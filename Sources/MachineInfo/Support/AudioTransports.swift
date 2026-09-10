//
//  AudioTransports.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import CoreAudio
import Foundation

/// CoreAudio's transport codes, named.
enum AudioTransports {

    /// The transport for a four-character code; `.other` for one not listed.
    static func transport(forCode code: UInt32) -> AudioTransport {
        switch code {
        case kAudioDeviceTransportTypeBuiltIn: .builtIn
        case kAudioDeviceTransportTypeUSB: .usb
        case kAudioDeviceTransportTypeBluetooth: .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE: .bluetoothLowEnergy
        case kAudioDeviceTransportTypeHDMI: .hdmi
        case kAudioDeviceTransportTypeDisplayPort: .displayPort
        case kAudioDeviceTransportTypeThunderbolt: .thunderbolt
        case kAudioDeviceTransportTypeAirPlay: .airPlay
        case kAudioDeviceTransportTypeVirtual: .virtual
        case kAudioDeviceTransportTypeAggregate: .aggregate
        case kAudioDeviceTransportTypePCI: .pci
        case kAudioDeviceTransportTypeFireWire: .fireWire
        case kAudioDeviceTransportTypeAVB: .avb
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless: .continuityCapture
        default: .other
        }
    }

    /// The code as its four characters, e.g. `bltn`; a code with
    /// unprintable bytes is given as hex instead.
    static func text(forCode code: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        guard bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) else {
            return String(format: "0x%08x", code)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
