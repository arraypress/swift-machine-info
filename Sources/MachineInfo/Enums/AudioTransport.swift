//
//  AudioTransport.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How an audio device is connected.
///
/// CoreAudio reports a four-character code; these are the ones that occur
/// on a Mac, named. `other` keeps the code on ``AudioDevice/transportCode``
/// so nothing is lost when a new bus appears.
public enum AudioTransport: String, Codable, Sendable, CaseIterable {
    case builtIn, usb, bluetooth, bluetoothLowEnergy, hdmi, displayPort, thunderbolt
    case airPlay, virtual, aggregate, pci, fireWire, avb, continuityCapture, other
}
