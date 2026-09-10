//
//  AudioDevices.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The audio devices CoreAudio knows, and which one sound goes to.
//

import CoreAudio
import Foundation

/// The audio devices on this Mac.
public enum AudioDevices {

    /// Every device, inputs and outputs, in CoreAudio's order.
    public static func all() -> [AudioDevice] {
        let defaultOutput = CoreAudioQueries.defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
        let defaultInput = CoreAudioQueries.defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
        return CoreAudioQueries.deviceIDs().compactMap {
            CoreAudioQueries.device($0, defaultOutput: defaultOutput, defaultInput: defaultInput)
        }
    }

    /// The device sound currently goes to, or nil when there is none — a
    /// Mac mini with nothing plugged in, or a headless session.
    public static func output() -> AudioDevice? {
        all().first(where: \.isDefaultOutput)
    }

    /// The device the microphone is, or nil.
    public static func input() -> AudioDevice? {
        all().first(where: \.isDefaultInput)
    }

    /// Makes a device the default output.
    ///
    /// A user-visible change: the sound menu flips, and whatever is playing
    /// moves. Say so before doing it on someone else's behalf.
    ///
    /// - Throws: ``MachineInfoError/audioDeviceNotFound(_:)`` when the id
    ///   is not an output device, ``MachineInfoError/audioError(_:)`` when
    ///   CoreAudio refuses.
    public static func setOutput(id: UInt32) throws {
        guard all().contains(where: { $0.id == id && $0.isOutput }) else {
            throw MachineInfoError.audioDeviceNotFound("device \(id)")
        }
        try CoreAudioQueries.setDefaultOutput(id)
    }

    /// Makes a device the default output, found by name.
    ///
    /// Case-insensitive, and a prefix or substring will do (`AirPods` for
    /// `David's AirPods Pro`) as long as it names exactly one output.
    ///
    /// - Throws: ``MachineInfoError/audioDeviceNotFound(_:)`` when no output
    ///   matches or more than one does.
    @discardableResult
    public static func setOutput(named name: String) throws -> AudioDevice {
        let outputs = all().filter(\.isOutput)
        guard let device = AudioMatching.match(name, in: outputs) else {
            throw MachineInfoError.audioDeviceNotFound(name)
        }
        try CoreAudioQueries.setDefaultOutput(device.id)
        return device
    }
}
