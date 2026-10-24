//
//  ConnectedDevice.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A Bluetooth or USB device: paired, plugged in, or both at once (a
/// keyboard charging on its cable is one device, not two).
///
/// Deliberately without serial numbers or Bluetooth addresses: they are
/// read only to match one device's entries together.
public struct ConnectedDevice: Codable, Sendable, Equatable {

    /// The name macOS shows, e.g. `Magic Keyboard with Touch ID`.
    public let name: String

    /// What it is, lower-cased, as macOS classes it: `headphones`,
    /// `keyboard`, `mouse`… `nil` when macOS does not say.
    public let kind: String?

    /// How it is attached right now; empty for a paired device that is off
    /// or out of range.
    public let connections: [DeviceConnection]

    /// Whether it is paired over Bluetooth.
    public let isPaired: Bool

    /// Its battery, when it reports one.
    public let battery: DeviceBattery?

    /// The maker, from USB (`Apple Inc.`), when known.
    public let vendor: String?

    /// USB link speed (`12 Mb/s`) and the power the Mac allots it (`2.5 W (500 mA)`).
    public let usbSpeed: String?
    public let usbPower: String?

    /// Whether it is attached at all.
    public var isConnected: Bool { !connections.isEmpty }

    /// A device, for callers building one by hand — a fixture, a test.
    public init(name: String, kind: String?, connections: [DeviceConnection], isPaired: Bool, battery: DeviceBattery?,
                vendor: String?, usbSpeed: String?, usbPower: String?) {
        self.name = name
        self.kind = kind
        self.connections = connections
        self.isPaired = isPaired
        self.battery = battery
        self.vendor = vendor
        self.usbSpeed = usbSpeed
        self.usbPower = usbPower
    }
}

/// How a device is attached.
public enum DeviceConnection: String, Codable, Sendable {
    case bluetooth
    case usb
}

/// A device's battery, in percent. Earbuds report each bud and the case;
/// everything else one level.
public struct DeviceBattery: Codable, Sendable, Equatable {

    /// The one level, for a device with one battery.
    public let percent: Int?

    /// Each earbud and the case.
    public let left: Int?
    public let right: Int?
    public let `case`: Int?

    /// Whether it is charging, where the device says (`nil` when it does not).
    public let charging: Bool?

    public init(percent: Int?, left: Int?, right: Int?, case: Int?, charging: Bool?) {
        self.percent = percent
        self.left = left
        self.right = right
        self.case = `case`
        self.charging = charging
    }

    /// The lowest level it reports — what decides when it needs charging.
    public var lowest: Int? { [percent, left, right].compactMap { $0 }.min() }
}
