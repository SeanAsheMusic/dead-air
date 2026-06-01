import Darwin
import Foundation

public final class OSCServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dead-air.osc-server", qos: .userInitiated)
    private let lock = NSLock()
    private var socketFD: Int32 = -1
    private var isRunning = false
    private var generation = 0
    private var handler: (@Sendable (RoutedCommand) -> Void)?

    public init() {}

    deinit {
        stop()
    }

    public func start(config: OSCConfig, handler: @escaping @Sendable (RoutedCommand) -> Void) throws {
        stop()
        guard config.enabled else { return }

        self.handler = handler
        let newSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard newSocket >= 0 else {
            throw NSError(domain: "DeadAir.OSC", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not create OSC UDP socket."])
        }

        var reuse: Int32 = 1
        setsockopt(newSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(config.port).bigEndian
        inet_pton(AF_INET, config.host, &address.sin_addr)

        let bindStatus = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(newSocket, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindStatus == 0 else {
            let code = errno
            close(newSocket)
            throw NSError(domain: "DeadAir.OSC", code: Int(code), userInfo: [NSLocalizedDescriptionKey: "Could not bind OSC UDP port \(config.port)."])
        }

        let activeGeneration: Int
        lock.lock()
        generation += 1
        activeGeneration = generation
        socketFD = newSocket
        isRunning = true
        lock.unlock()

        queue.async { [weak self] in
            self?.receiveLoop(socketFD: newSocket, generation: activeGeneration, acceptLocalhostOnly: config.acceptLocalhostOnly)
        }
        Diagnostics.shared.record(LogEvent(source: "osc", message: "OSC listener online", raw: "\(config.host):\(config.port)"))
    }

    public func stop() {
        lock.lock()
        isRunning = false
        generation += 1
        let oldSocket = socketFD
        socketFD = -1
        lock.unlock()

        if oldSocket >= 0 {
            shutdown(oldSocket, SHUT_RDWR)
            close(oldSocket)
        }
    }

    private func receiveLoop(socketFD: Int32, generation: Int, acceptLocalhostOnly: Bool) {
        var buffer = [UInt8](repeating: 0, count: 4096)

        while isActive(socketFD: socketFD, generation: generation) {
            var remote = sockaddr_in()
            var remoteLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &remote) { remotePointer in
                remotePointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    recvfrom(socketFD, &buffer, buffer.count, 0, sockaddrPointer, &remoteLength)
                }
            }

            guard count > 0 else {
                if !isActive(socketFD: socketFD, generation: generation) {
                    break
                }
                continue
            }
            if acceptLocalhostOnly, remote.sin_addr.s_addr != in_addr_t(0x0100007F) {
                continue
            }

            let data = Data(buffer.prefix(Int(count)))
            guard let command = OSCParser.command(from: data) else { continue }
            let raw = String(data: data, encoding: .utf8) ?? "\(count) bytes"
            handler?(RoutedCommand(command: command, source: .oscLocal, rawSummary: raw))
        }
    }

    private func isActive(socketFD: Int32, generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning && self.socketFD == socketFD && self.generation == generation
    }
}
