@preconcurrency import AVFAudio
import AudioToolbox
import Foundation

public enum AudioEngineError: Error, LocalizedError {
    case unsupportedFile(URL)
    case missingActiveBuffer
    case couldNotCreateFormat
    case conversionFailed(String)
    case outputDeviceUnavailable(String)
    case outputRouteFailed(String)
    case fileTooLarge(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url): "Unsupported audio file: \(url.lastPathComponent)"
        case .missingActiveBuffer: "No active audio bed is loaded."
        case .couldNotCreateFormat: "Could not create the requested audio format."
        case .conversionFailed(let message): "Audio conversion failed: \(message)"
        case .outputDeviceUnavailable(let uid): "Output device is unavailable: \(uid)"
        case .outputRouteFailed(let message): "Output routing failed: \(message)"
        case .fileTooLarge(let message): message
        }
    }
}

public final class AudioEngineController: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dead-air.audio-engine", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let playerA = AVAudioPlayerNode()
    private let playerB = AVAudioPlayerNode()
    private let mixerA = AVAudioMixerNode()
    private let mixerB = AVAudioMixerNode()
    private let master = AVAudioMixerNode()
    private let queueKey = DispatchSpecificKey<Void>()
    private var graphBuilt = false
    private var activeMixer: AVAudioMixerNode
    private var activePlayer: AVAudioPlayerNode
    private var activeBuffer: AVAudioPCMBuffer?
    private var fadeTimer: DispatchSourceTimer?
    private var fadeID = UUID()
    private var targetGain: Float = FadeMath.dbToLinear(-14.0)
    private var configurationChangeObserver: NSObjectProtocol?
    private var configurationChangeHandler: (@Sendable () -> Void)?

    public init() {
        activeMixer = mixerA
        activePlayer = playerA
        queue.setSpecific(key: queueKey, value: ())
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Diagnostics.shared.record(LogEvent(source: "audio", message: "engine configuration changed"))
            self?.configurationChangeHandler?()
        }
    }

    deinit {
        if let configurationChangeObserver {
            NotificationCenter.default.removeObserver(configurationChangeObserver)
        }
    }

    public var currentGain: Float {
        syncOnQueue { activeMixer.outputVolume }
    }

    public var engineOutputSummary: String {
        syncOnQueue {
            let format = engine.outputNode.outputFormat(forBus: 0)
            let status = engine.isRunning ? "running" : "stopped"
            return "\(Int(format.sampleRate)) Hz | \(format.channelCount) ch | \(status)"
        }
    }

    public func setConfigurationChangeHandler(_ handler: (@Sendable () -> Void)?) {
        queue.async {
            self.configurationChangeHandler = handler
        }
    }

    public func buildGraph(sampleRate: Double, outputUID: String? = nil, leftChannel: Int = 1, rightChannel: Int = 2) throws {
        try syncOnQueue {
            if graphBuilt {
                engine.stop()
                engine.reset()
            } else {
                [playerA, playerB, mixerA, mixerB, master].forEach(engine.attach)
                graphBuilt = true
            }

            try applyOutputRoute(outputUID: outputUID, leftChannel: leftChannel, rightChannel: rightChannel)

            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false) else {
                throw AudioEngineError.couldNotCreateFormat
            }

            engine.disconnectNodeInput(mixerA)
            engine.disconnectNodeInput(mixerB)
            engine.disconnectNodeInput(master)
            engine.disconnectNodeInput(engine.mainMixerNode)

            engine.connect(playerA, to: mixerA, format: format)
            engine.connect(playerB, to: mixerB, format: format)
            engine.connect(mixerA, to: master, format: format)
            engine.connect(mixerB, to: master, format: format)
            engine.connect(master, to: engine.mainMixerNode, format: format)

            mixerA.outputVolume = 0
            mixerB.outputVolume = 0
            master.outputVolume = 1

            engine.prepare()
            try engine.start()
            Diagnostics.shared.record(LogEvent(source: "audio", message: "engine built", raw: "\(Int(sampleRate)) Hz | \(leftChannel)-\(rightChannel)"))
        }
    }

    public func rebuild(sampleRate: Double, outputUID: String? = nil, leftChannel: Int = 1, rightChannel: Int = 2) throws {
        try buildGraph(sampleRate: sampleRate, outputUID: outputUID, leftChannel: leftChannel, rightChannel: rightChannel)
    }

    public func setTargetLevel(db: Double) {
        queue.async {
            self.targetGain = FadeMath.dbToLinear(db)
        }
    }

    public func setTargetLevel(linear: Double) {
        queue.async {
            self.targetGain = Float(max(0, min(1, linear)))
        }
    }

    public func loadBuffer(from url: URL, sampleRate: Double, maxPredecodedBytes: Int? = nil) throws -> AVAudioPCMBuffer {
        guard AudioFormatSupport.isSupportedAudioURL(url) else {
            throw AudioEngineError.unsupportedFile(url)
        }

        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let sourceFrameCount = AVAudioFrameCount(min(file.length, Int64(UInt32.max)))
        let sourceBytes = estimatedBytes(frameCount: sourceFrameCount, format: sourceFormat)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false) else {
            throw AudioEngineError.couldNotCreateFormat
        }

        let canUseSourceBuffer = sourceFormat.sampleRate == sampleRate
            && sourceFormat.channelCount == 2
            && sourceFormat.commonFormat == .pcmFormatFloat32
            && !sourceFormat.isInterleaved
        let duration = sourceFormat.sampleRate > 0 ? Double(sourceFrameCount) / sourceFormat.sampleRate : 0
        let targetFrameCapacity = AVAudioFrameCount(max(1, ceil(duration * sampleRate)))
        let targetBytes = estimatedBytes(frameCount: targetFrameCapacity, format: targetFormat)
        if let maxPredecodedBytes {
            let estimatedPeakBytes = canUseSourceBuffer ? sourceBytes : sourceBytes + targetBytes
            if estimatedPeakBytes > maxPredecodedBytes {
                throw AudioEngineError.fileTooLarge(fileTooLargeMessage(url: url, estimatedBytes: estimatedPeakBytes, maxBytes: maxPredecodedBytes))
            }
        }

        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: sourceFrameCount) else {
            throw AudioEngineError.couldNotCreateFormat
        }
        try file.read(into: sourceBuffer)

        if canUseSourceBuffer {
            return sourceBuffer
        }

        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCapacity) else {
            throw AudioEngineError.couldNotCreateFormat
        }
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AudioEngineError.conversionFailed("converter unavailable")
        }

        let inputState = ConverterInputState()
        var conversionError: NSError?
        converter.convert(to: targetBuffer, error: &conversionError) { _, status in
            if inputState.providedInput {
                status.pointee = .noDataNow
                return nil
            }
            inputState.providedInput = true
            status.pointee = .haveData
            return sourceBuffer
        }

        if let conversionError {
            throw AudioEngineError.conversionFailed(conversionError.localizedDescription)
        }
        if targetBuffer.frameLength == 0, sourceBuffer.frameLength > 0 {
            throw AudioEngineError.conversionFailed("converter produced no audio frames")
        }

        return targetBuffer
    }

    public func prime(url: URL, sampleRate: Double, muted: Bool = true, maxPredecodedBytes: Int? = nil) throws {
        let buffer = try loadBuffer(from: url, sampleRate: sampleRate, maxPredecodedBytes: maxPredecodedBytes)
        syncOnQueue {
            self.activeBuffer = buffer
            self.primeOnQueue(buffer: buffer, muted: muted)
        }
    }

    private func primeOnQueue(buffer: AVAudioPCMBuffer, muted: Bool = true) {
        activePlayer.stop()
        activePlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        activeMixer.outputVolume = muted ? 0 : targetGain
        if !activePlayer.isPlaying {
            activePlayer.play()
        }
        Diagnostics.shared.record(LogEvent(source: "audio", message: "bed primed", raw: "\(buffer.frameLength) frames"))
    }

    public func crossfadeTo(url: URL, sampleRate: Double, durationMs: Int, maxPredecodedBytes: Int? = nil, completion: @escaping @Sendable () -> Void) throws {
        let buffer = try loadBuffer(from: url, sampleRate: sampleRate, maxPredecodedBytes: maxPredecodedBytes)
        queue.async {
            self.crossfadeTo(buffer: buffer, durationMs: durationMs, completion: completion)
        }
    }

    public func fadeIn(durationMs: Int, completion: @escaping @Sendable () -> Void) {
        queue.async {
            guard self.activeBuffer != nil else { return }
            if !self.engine.isRunning {
                try? self.engine.start()
            }
            if !self.activePlayer.isPlaying {
                self.activePlayer.play()
            }
            self.startFade(to: self.targetGain, durationMs: durationMs, completion: completion)
        }
    }

    public func fadeOut(durationMs: Int, completion: @escaping @Sendable () -> Void) {
        queue.async {
            self.startFade(to: 0, durationMs: durationMs, completion: completion)
        }
    }

    public func panicMute() {
        queue.async {
            self.cancelFade()
            self.mixerA.outputVolume = 0
            self.mixerB.outputVolume = 0
            Diagnostics.shared.record(LogEvent(source: "audio", message: "panic mute"))
        }
    }

    private func startFade(to endGain: Float, durationMs: Int, completion: @escaping @Sendable () -> Void) {
        cancelFade()

        let localFadeID = UUID()
        fadeID = localFadeID
        let startGain = activeMixer.outputVolume
        let duration = max(1, durationMs)
        let started = DispatchTime.now()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, self.fadeID == localFadeID else { return }
            let elapsedNs = DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds
            let elapsedMs = Double(elapsedNs) / 1_000_000.0
            let t = min(1, elapsedMs / Double(duration))
            let shaped = Float(FadeMath.equalPower(t))
            let gain = startGain + ((endGain - startGain) * shaped)
            self.activeMixer.outputVolume = gain

            if t >= 1 {
                self.activeMixer.outputVolume = endGain
                self.cancelFade()
                completion()
            }
        }
        fadeTimer = timer
        timer.resume()
        Diagnostics.shared.record(LogEvent(source: "audio", message: "fade started", raw: "\(durationMs) ms"))
    }

    private func cancelFade() {
        fadeTimer?.cancel()
        fadeTimer = nil
    }

    private func crossfadeTo(buffer: AVAudioPCMBuffer, durationMs: Int, completion: @escaping @Sendable () -> Void) {
        cancelFade()

        if !engine.isRunning {
            try? engine.start()
        }

        let outgoingPlayer = activePlayer
        let outgoingMixer = activeMixer
        let incomingPlayer = activePlayer === playerA ? playerB : playerA
        let incomingMixer = activeMixer === mixerA ? mixerB : mixerA

        incomingPlayer.stop()
        incomingPlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        incomingMixer.outputVolume = 0
        if !incomingPlayer.isPlaying {
            incomingPlayer.play()
        }
        if !outgoingPlayer.isPlaying {
            outgoingPlayer.play()
        }

        let localFadeID = UUID()
        fadeID = localFadeID
        let startOutgoing = max(outgoingMixer.outputVolume, targetGain)
        let duration = max(1, durationMs)
        let started = DispatchTime.now()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self, self.fadeID == localFadeID else { return }
            let elapsedNs = DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds
            let elapsedMs = Double(elapsedNs) / 1_000_000.0
            let t = min(1, elapsedMs / Double(duration))
            let angle = Float(t * .pi / 2.0)
            outgoingMixer.outputVolume = startOutgoing * cos(angle)
            incomingMixer.outputVolume = self.targetGain * sin(angle)

            if t >= 1 {
                outgoingMixer.outputVolume = 0
                incomingMixer.outputVolume = self.targetGain
                outgoingPlayer.stop()
                self.activePlayer = incomingPlayer
                self.activeMixer = incomingMixer
                self.activeBuffer = buffer
                self.cancelFade()
                Diagnostics.shared.record(LogEvent(source: "audio", message: "crossfade complete", raw: "\(durationMs) ms"))
                completion()
            }
        }
        fadeTimer = timer
        timer.resume()
        Diagnostics.shared.record(LogEvent(source: "audio", message: "crossfade started", raw: "\(durationMs) ms"))
    }

    private func applyOutputRoute(outputUID: String?, leftChannel: Int, rightChannel: Int) throws {
        guard let audioUnit = engine.outputNode.audioUnit else {
            throw AudioEngineError.outputRouteFailed("Output audio unit is not available.")
        }

        let resolvedUID = outputUID ?? CoreAudioDeviceManager.defaultOutputUID()
        if let resolvedUID {
            guard let deviceID = CoreAudioDeviceManager.audioDeviceID(forUID: resolvedUID) else {
                throw AudioEngineError.outputDeviceUnavailable(resolvedUID)
            }

            var mutableDeviceID = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status != noErr {
                throw AudioEngineError.outputRouteFailed("Could not bind engine to selected device (\(status)).")
            }
        }

        let channelCount = CoreAudioDeviceManager.outputChannelCount(forUID: outputUID)
        guard channelCount >= 2 else { return }
        guard leftChannel >= 1, rightChannel >= 1, leftChannel <= channelCount, rightChannel <= channelCount, leftChannel != rightChannel else {
            throw AudioEngineError.outputRouteFailed("Invalid output channel pair \(leftChannel)-\(rightChannel).")
        }

        var channelMap = Array(repeating: Int32(-1), count: channelCount)
        channelMap[leftChannel - 1] = 0
        channelMap[rightChannel - 1] = 1
        let byteCount = UInt32(channelMap.count * MemoryLayout<Int32>.size)
        let status = channelMap.withUnsafeMutableBufferPointer { buffer in
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_ChannelMap,
                kAudioUnitScope_Output,
                0,
                buffer.baseAddress,
                byteCount
            )
        }

        if status != noErr {
            Diagnostics.shared.record(LogEvent(source: "audio", message: "channel map rejected", raw: "status \(status); using device default"))
        } else {
            Diagnostics.shared.record(LogEvent(source: "audio", message: "channel map applied", raw: "\(leftChannel)-\(rightChannel) of \(channelCount)"))
        }
    }

    private func syncOnQueue<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try work()
        }
        return try queue.sync(execute: work)
    }

    private func estimatedBytes(frameCount: AVAudioFrameCount, format: AVAudioFormat) -> Int {
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        if bytesPerFrame > 0 {
            return Int(frameCount) * bytesPerFrame
        }
        let bytesPerSample: Int
        switch format.commonFormat {
        case .pcmFormatFloat64:
            bytesPerSample = 8
        case .pcmFormatFloat32, .pcmFormatInt32:
            bytesPerSample = 4
        case .pcmFormatInt16:
            bytesPerSample = 2
        case .otherFormat:
            bytesPerSample = 4
        @unknown default:
            bytesPerSample = 4
        }
        return Int(frameCount) * Int(format.channelCount) * bytesPerSample
    }

    private func fileTooLargeMessage(url: URL, estimatedBytes: Int, maxBytes: Int) -> String {
        let estimatedMB = max(1, estimatedBytes / 1_048_576)
        let maxMB = max(1, maxBytes / 1_048_576)
        return "\(url.lastPathComponent) needs about \(estimatedMB) MB predecoded, above the current \(maxMB) MB safety limit."
    }
}

private final class ConverterInputState: @unchecked Sendable {
    var providedInput = false
}
