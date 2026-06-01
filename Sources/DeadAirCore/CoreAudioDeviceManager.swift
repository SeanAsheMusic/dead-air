import AudioToolbox
import CoreAudio
import Foundation

public struct AudioOutputDevice: Identifiable, Codable, Equatable, Sendable {
    public var id: String { uid }
    public var uid: String
    public var name: String
    public var nominalSampleRate: Double
    public var channelCount: Int
    public var isDefault: Bool

    public init(uid: String, name: String, nominalSampleRate: Double, channelCount: Int, isDefault: Bool) {
        self.uid = uid
        self.name = name
        self.nominalSampleRate = nominalSampleRate
        self.channelCount = channelCount
        self.isDefault = isDefault
    }
}

public enum CoreAudioDeviceManager {
    public static func outputDevices() -> [AudioOutputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        let defaultID = defaultOutputDeviceID()
        return deviceIDs.compactMap { id in
            let channelCount = outputChannelCount(for: id)
            guard channelCount > 0,
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, deviceID: id),
                  let name = stringProperty(kAudioObjectPropertyName, deviceID: id)
            else {
                return nil
            }
            return AudioOutputDevice(
                uid: uid,
                name: name,
                nominalSampleRate: nominalSampleRate(for: id),
                channelCount: channelCount,
                isDefault: id == defaultID
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public static func setDefaultOutputDevice(uid: String) throws {
        guard let deviceID = audioDeviceID(forUID: uid) else {
            throw NSError(domain: "DeadAir.CoreAudio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Output device not found."])
        }

        var mutableDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        if status != noErr {
            throw NSError(domain: "DeadAir.CoreAudio", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not select output device."])
        }
    }

    public static func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        outputDevicesWithIDs().first(where: { $0.uid == uid })?.deviceID
    }

    public static func outputChannelCount(forUID uid: String?) -> Int {
        if let uid, let deviceID = audioDeviceID(forUID: uid) {
            return outputChannelCount(for: deviceID)
        }
        return outputChannelCount(for: defaultOutputDeviceID())
    }

    public static func defaultOutputUID() -> String? {
        stringProperty(kAudioDevicePropertyDeviceUID, deviceID: defaultOutputDeviceID())
    }

    public static func channelPairs(forUID uid: String?) -> [(left: Int, right: Int)] {
        let count = outputChannelCount(forUID: uid)
        guard count >= 2 else { return [] }
        return stride(from: 1, through: count - 1, by: 2).map { ($0, $0 + 1) }
    }

    private static func outputDevicesWithIDs() -> [(deviceID: AudioDeviceID, uid: String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return []
        }
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }
        return deviceIDs.compactMap { id in
            guard outputChannelCount(for: id) > 0, let uid = stringProperty(kAudioDevicePropertyDeviceUID, deviceID: id) else { return nil }
            return (id, uid)
        }
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID)
        return deviceID
    }

    private static func outputChannelCount(for deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer) == noErr else { return 0 }
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func nominalSampleRate(for deviceID: AudioDeviceID) -> Double {
        var rate = Float64(0)
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &rate) == noErr else { return 0 }
        return rate
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, deviceID: AudioDeviceID) -> String? {
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
