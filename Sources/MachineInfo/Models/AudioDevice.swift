//
//  AudioDevice.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One audio device, as CoreAudio lists it.
public struct AudioDevice: Codable, Sendable, Equatable {

    /// CoreAudio's device identifier; valid until the device is unplugged.
    public let id: UInt32

    /// The name shown in Sound settings, e.g. `MacBook Pro Speakers`.
    public let name: String

    /// A stable identifier that survives reboots, e.g. `BuiltInSpeakerDevice`.
    public let uid: String?

    /// How it is connected.
    public let transport: AudioTransport

    /// CoreAudio's own four-character code for the transport, e.g. `bltn`.
    public let transportCode: String

    /// Whether it has input streams (a microphone).
    public let isInput: Bool

    /// Whether it has output streams (speakers, headphones).
    public let isOutput: Bool

    /// Whether it is the current default output.
    public let isDefaultOutput: Bool

    /// Whether it is the current default input.
    public let isDefaultInput: Bool

    /// The nominal sample rate in hertz, where readable.
    public let sampleRate: Double?
}
