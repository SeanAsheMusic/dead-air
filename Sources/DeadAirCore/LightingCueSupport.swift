import Foundation

public enum OSCArgument: Equatable, Sendable {
    case float32(Float)
    case int32(Int32)
    case string(String)
}

public enum OSCMessageBuilder {
    public static func packet(address: String, arguments: [OSCArgument] = []) -> Data {
        var data = Data()
        data.append(paddedOSCString(address))
        data.append(paddedOSCString(typeTags(for: arguments)))
        for argument in arguments {
            switch argument {
            case .float32(let value):
                var bits = value.bitPattern.bigEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            case .int32(let value):
                var number = value.bigEndian
                withUnsafeBytes(of: &number) { data.append(contentsOf: $0) }
            case .string(let value):
                data.append(paddedOSCString(value))
            }
        }
        return data
    }

    private static func typeTags(for arguments: [OSCArgument]) -> String {
        "," + arguments.map { argument in
            switch argument {
            case .float32: "f"
            case .int32: "i"
            case .string: "s"
            }
        }.joined()
    }

    private static func paddedOSCString(_ string: String) -> Data {
        var bytes = Array(string.utf8)
        bytes.append(0)
        while bytes.count % 4 != 0 {
            bytes.append(0)
        }
        return Data(bytes)
    }
}

public enum LightkeyOSCAddress {
    public static let forbiddenPartCharacters = CharacterSet(charactersIn: "#*,/?[]{}")

    public static func normalizedPart(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
    }

    public static func invalidCharacters(in value: String) -> [String] {
        let scalars = value.unicodeScalars.filter { forbiddenPartCharacters.contains($0) }
        return Array(Set(scalars.map { String($0) })).sorted()
    }

    public static func generatedAddress(for cue: LightingCue) -> String? {
        if let raw = cue.rawOSCAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }

        let page = normalizedPart(cue.pageName)
        let frame = normalizedPart(cue.frameName ?? "")
        let cueName = normalizedPart(cue.cueName)
        guard !page.isEmpty else { return nil }

        switch cue.action {
        case .selectPage:
            return "/live/\(page)/select"
        case .nextCue:
            if frame.isEmpty {
                return "/live/\(page)/nextCue"
            }
            return "/live/\(page)/frame/\(frame)/nextCue"
        case .previousCue:
            if frame.isEmpty {
                return "/live/\(page)/previousCue"
            }
            return "/live/\(page)/frame/\(frame)/previousCue"
        case .activate, .deactivate, .toggle, .intensity:
            guard !cueName.isEmpty else { return nil }
            if frame.isEmpty {
                return "/live/\(page)/cue/\(cueName)/\(cue.action.rawValue)"
            }
            return "/live/\(page)/frame/\(frame)/cue/\(cueName)/\(cue.action.rawValue)"
        }
    }
}

public extension LightingCue {
    var lightkeyAddress: String? {
        LightkeyOSCAddress.generatedAddress(for: self)
    }

    var oscAddress: String? {
        switch provider {
        case .lightkeyOSC:
            return lightkeyAddress
        case .customOSC:
            let raw = rawOSCAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? nil : raw
        case .midi:
            return nil
        }
    }

    var oscArguments: [OSCArgument] {
        switch action {
        case .intensity:
            let value = max(0, min(1, intensity ?? 1))
            return [.float32(Float(value))]
        case .activate, .deactivate, .toggle, .selectPage, .nextCue, .previousCue:
            guard let fadeTimeSeconds else { return [] }
            return [.float32(Float(max(0, fadeTimeSeconds)))]
        }
    }

    var displaySummary: String {
        switch provider {
        case .lightkeyOSC:
            return lightkeyAddress ?? "Lightkey OSC not configured"
        case .customOSC:
            return oscAddress ?? "Custom OSC address required"
        case .midi:
            return "\(midiMessageType.displayName) Ch \(midiChannel) #\(midiNumber) Val \(midiValue)"
        }
    }

    func validationWarnings(config: LightingConfig) -> [String] {
        guard enabled else { return [] }
        var warnings: [String] = []

        switch provider {
        case .lightkeyOSC, .customOSC:
            if config.lightkeyHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("OSC host is empty.")
            }
            if !(1 ... 65_535).contains(config.lightkeyPort) {
                warnings.append("OSC port must be 1-65535.")
            }

            if let raw = rawOSCAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                if !raw.hasPrefix("/") {
                    warnings.append("Raw OSC address must start with '/'.")
                }
                if raw.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                    warnings.append("Raw OSC address cannot contain spaces.")
                }
            } else if provider == .customOSC {
                warnings.append("Custom OSC address is required.")
            } else {
                let page = pageName.trimmingCharacters(in: .whitespacesAndNewlines)
                if page.isEmpty {
                    warnings.append("Lightkey page is empty.")
                }
                let pageInvalid = LightkeyOSCAddress.invalidCharacters(in: page)
                if !pageInvalid.isEmpty {
                    warnings.append("Lightkey page has invalid characters: \(pageInvalid.joined(separator: " ")).")
                }
                if let frameName, !frameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let frameInvalid = LightkeyOSCAddress.invalidCharacters(in: frameName)
                    if !frameInvalid.isEmpty {
                        warnings.append("Lightkey frame has invalid characters: \(frameInvalid.joined(separator: " ")).")
                    }
                }
                if action.requiresCueName {
                    let cue = cueName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cue.isEmpty {
                        warnings.append("Lightkey cue is empty.")
                    }
                    let cueInvalid = LightkeyOSCAddress.invalidCharacters(in: cue)
                    if !cueInvalid.isEmpty {
                        warnings.append("Lightkey cue has invalid characters: \(cueInvalid.joined(separator: " ")).")
                    }
                }
            }
        case .midi:
            if config.midiDestinationUniqueID == nil,
               config.midiDestinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("MIDI destination is empty.")
            }
            if !(1 ... 16).contains(midiChannel) {
                warnings.append("MIDI channel must be 1-16.")
            }
            if !(0 ... 127).contains(midiNumber) {
                warnings.append("MIDI number must be 0-127.")
            }
            if !(0 ... 127).contains(midiValue) {
                warnings.append("MIDI value must be 0-127.")
            }
        }

        return warnings
    }

    static func template(trigger: LightingCueTrigger, provider: LightingProvider = .lightkeyOSC) -> LightingCue {
        let rawOSCAddress = provider == .customOSC ? "/deadAir/\(trigger.rawValue)" : nil
        return LightingCue(
            enabled: true,
            name: trigger.displayName,
            trigger: trigger,
            provider: provider,
            pageName: "Live",
            cueName: "Transition",
            action: .activate,
            rawOSCAddress: rawOSCAddress
        )
    }
}

public extension LightingConfig {
    var enabledCueCount: Int {
        cues.filter(\.enabled).count
    }

    func validationWarnings(for bedCues: [LightingCue] = []) -> [String] {
        guard enabled else { return [] }
        let allCues = cues + bedCues
        if allCues.filter(\.enabled).isEmpty {
            return ["Lighting is enabled but no cues are enabled."]
        }
        return allCues.flatMap { cue in
            cue.validationWarnings(config: self).map { "\(cue.name): \($0)" }
        }
    }
}
