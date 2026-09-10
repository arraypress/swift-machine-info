//
//  CoreAudioQueries.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The CoreAudio property reads, in one place. Every read is a property
//  address and a buffer; the shape is the same each time, so it is written
//  once.
//

import CoreAudio
import Foundation

/// Reading and writing CoreAudio properties.
enum CoreAudioQueries {

    /// Every device the HAL lists.
    static func deviceIDs() -> [AudioDeviceID] {
        var address = global(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    /// The default device for a selector (output or input), or nil.
    static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = global(selector)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != 0 else { return nil }
        return id
    }

    /// One device as a value; nil when it has no name, which is what an
    /// unplugged-mid-read device looks like.
    static func device(_ id: AudioDeviceID, defaultOutput: AudioDeviceID?, defaultInput: AudioDeviceID?) -> AudioDevice? {
        guard let name = string(id, kAudioObjectPropertyName) else { return nil }
        let code = uint32(id, kAudioDevicePropertyTransportType) ?? 0
        return AudioDevice(
            id: id,
            name: name,
            uid: string(id, kAudioDevicePropertyDeviceUID),
            transport: AudioTransports.transport(forCode: code),
            transportCode: AudioTransports.text(forCode: code),
            isInput: streamCount(id, scope: kAudioObjectPropertyScopeInput) > 0,
            isOutput: streamCount(id, scope: kAudioObjectPropertyScopeOutput) > 0,
            isDefaultOutput: id == defaultOutput,
            isDefaultInput: id == defaultInput,
            sampleRate: float64(id, kAudioDevicePropertyNominalSampleRate)
        )
    }

    /// Makes a device the system's default output.
    static func setDefaultOutput(_ id: AudioDeviceID) throws {
        var address = global(kAudioHardwarePropertyDefaultOutputDevice)
        var value = id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &value
        )
        guard status == noErr else { throw MachineInfoError.audioError(status) }
    }

    // MARK: Reads

    private static func global(_ selector: AudioObjectPropertySelector,
                               scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = global(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func uint32(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = global(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func float64(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> Double? {
        var address = global(selector)
        var value: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, value > 0 else { return nil }
        return value
    }

    /// How many streams a device has in a direction; zero means it does
    /// not do that direction at all.
    private static func streamCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = global(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioStreamID>.size
    }
}
