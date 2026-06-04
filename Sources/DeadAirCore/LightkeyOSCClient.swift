import Darwin
import Foundation

public struct LightingCueSendResult: Sendable {
    public var success: Bool
    public var provider: LightingProvider
    public var trigger: LightingCueTrigger
    public var cueName: String
    public var target: String
    public var errorMessage: String?

    public init(
        success: Bool,
        provider: LightingProvider,
        trigger: LightingCueTrigger,
        cueName: String,
        target: String,
        errorMessage: String? = nil
    ) {
        self.success = success
        self.provider = provider
        self.trigger = trigger
        self.cueName = cueName
        self.target = target
        self.errorMessage = errorMessage
    }
}

public final class LightkeyOSCClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dead-air.lightkey-osc-client", qos: .utility)

    public init() {}

    public func send(
        cue: LightingCue,
        config: LightingConfig,
        trigger: LightingCueTrigger,
        completion: @escaping @Sendable (LightingCueSendResult) -> Void
    ) {
        let warnings = cue.validationWarnings(config: config)
        guard warnings.isEmpty else {
            completion(
                LightingCueSendResult(
                    success: false,
                    provider: cue.provider,
                    trigger: trigger,
                    cueName: cue.name,
                    target: cue.displaySummary,
                    errorMessage: warnings.joined(separator: " ")
                )
            )
            return
        }

        guard let address = cue.oscAddress else {
            completion(
                LightingCueSendResult(
                    success: false,
                    provider: cue.provider,
                    trigger: trigger,
                    cueName: cue.name,
                    target: "unconfigured",
                    errorMessage: "Missing OSC address."
                )
            )
            return
        }

        guard let endpoint = cue.oscEndpoint(config: config) else {
            completion(
                LightingCueSendResult(
                    success: false,
                    provider: cue.provider,
                    trigger: trigger,
                    cueName: cue.name,
                    target: "unconfigured",
                    errorMessage: "Missing OSC endpoint."
                )
            )
            return
        }
        let host = endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = endpoint.port
        let packet = OSCMessageBuilder.packet(address: address, arguments: cue.oscArguments)

        queue.async {
            let sendError = Self.sendUDP(packet, host: host, port: port)
            completion(
                LightingCueSendResult(
                    success: sendError == nil,
                    provider: cue.provider,
                    trigger: trigger,
                    cueName: cue.name,
                    target: "\(host):\(port) \(address)",
                    errorMessage: sendError
                )
            )
        }
    }

    public func sendSynchronously(
        cue: LightingCue,
        config: LightingConfig,
        trigger: LightingCueTrigger
    ) -> LightingCueSendResult {
        let warnings = cue.validationWarnings(config: config)
        guard warnings.isEmpty else {
            return LightingCueSendResult(
                success: false,
                provider: cue.provider,
                trigger: trigger,
                cueName: cue.name,
                target: cue.displaySummary,
                errorMessage: warnings.joined(separator: " ")
            )
        }

        guard let address = cue.oscAddress else {
            return LightingCueSendResult(
                success: false,
                provider: cue.provider,
                trigger: trigger,
                cueName: cue.name,
                target: "unconfigured",
                errorMessage: "Missing OSC address."
            )
        }

        guard let endpoint = cue.oscEndpoint(config: config) else {
            return LightingCueSendResult(
                success: false,
                provider: cue.provider,
                trigger: trigger,
                cueName: cue.name,
                target: "unconfigured",
                errorMessage: "Missing OSC endpoint."
            )
        }
        let host = endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = endpoint.port
        let packet = OSCMessageBuilder.packet(address: address, arguments: cue.oscArguments)
        let sendError = Self.sendUDP(packet, host: host, port: port)
        return LightingCueSendResult(
            success: sendError == nil,
            provider: cue.provider,
            trigger: trigger,
            cueName: cue.name,
            target: "\(host):\(port) \(address)",
            errorMessage: sendError
        )
    }

    private static func sendUDP(_ data: Data, host: String, port: Int) -> String? {
        let resolvedHost = host == "localhost" ? "127.0.0.1" : host
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            return "Could not create UDP socket."
        }
        defer { close(socketFD) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        guard inet_pton(AF_INET, resolvedHost, &address.sin_addr) == 1 else {
            return "OSC host must be localhost or an IPv4 address."
        }

        let sent = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    sendto(socketFD, bytes.baseAddress, data.count, 0, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        if sent == data.count {
            return nil
        }
        return "OSC send failed with errno \(errno)."
    }
}
