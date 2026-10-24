//
//  DeviceDecoding.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Reading the three sources of device facts, and putting one device's
//  entries together. Pure.
//
//  MEASURED on macOS 27.0.1 (a MacBook Pro with AirPods Pro, a Magic
//  Keyboard and a Magic Mouse):
//  - `system_profiler SPBluetoothDataType -json`: `device_connected` and
//    `device_not_connected`, lists of `{name: {device_address,
//    device_minorType, device_productID, device_vendorID,
//    device_batteryLevel{Left,Right,Case}…}}`; levels are text, "98%".
//    AirPods' levels are ONLY here.
//  - `system_profiler SPUSBHostDataType -json`: buses (they carry `Driver`)
//    with `_items`, nested for hubs; a device has `_name`,
//    `USBDeviceKeyVendorName`, `…VendorID`/`…ProductID` ("0x05ac"),
//    `…LinkSpeed`, `…PowerAllocation`, `…SerialNumber` (never kept).
//  - IOKit `AppleDeviceManagementHIDEventService`: a keyboard, mouse or
//    trackpad's `BatteryPercent`, `BatteryStatusFlags`, `Transport`
//    ("Bluetooth" / "USB"), `DeviceAddress` ("aa-bb-cc-…", kept even while
//    on its cable) and `ProductID`. Not in system_profiler.
//  - `BatteryStatusFlags`: 4 on Bluetooth running on its battery, 3 on its
//    USB cable charging (one keyboard, both states). Other values are left
//    unread rather than guessed.
//

import Foundation

/// One paired Bluetooth device, as system_profiler lists it.
struct BluetoothEntry: Equatable {
    var name: String
    var address: String?
    var kind: String?
    var connected: Bool
    var productID: Int?
    var levels: [String: Int]
}

/// One USB device.
struct USBEntry: Equatable {
    var name: String
    var vendor: String?
    var vendorID: Int?
    var productID: Int?
    var speed: String?
    var power: String?
}

/// One HID device's battery, from IOKit.
struct HIDBattery: Equatable {
    var address: String?
    var productID: Int?
    var transport: String?
    var percent: Int
    var flags: Int?
}

enum DeviceDecoding {

    /// Paired Bluetooth devices from `system_profiler SPBluetoothDataType -json`'s object.
    static func bluetooth(_ root: [String: Any]) -> [BluetoothEntry] {
        let controllers = root["SPBluetoothDataType"] as? [[String: Any]] ?? []
        return controllers.flatMap { controller -> [BluetoothEntry] in
            [("device_connected", true), ("device_not_connected", false)].flatMap { key, connected -> [BluetoothEntry] in
                (controller[key] as? [[String: Any]] ?? []).flatMap { $0.map { name, value -> BluetoothEntry in
                    let info = value as? [String: Any] ?? [:]
                    var levels: [String: Int] = [:]
                    for (field, level) in info where field.hasPrefix("device_batteryLevel") {
                        if let percent = percent(level) { levels[String(field.dropFirst("device_batteryLevel".count))] = percent }
                    }
                    return BluetoothEntry(name: name, address: (info["device_address"] as? String).map(normalisedAddress),
                                          kind: (info["device_minorType"] as? String)?.lowercased(), connected: connected,
                                          productID: hex(info["device_productID"]), levels: levels)
                } }
            }
        }
    }

    /// USB devices from `system_profiler SPUSBHostDataType -json`'s object, hubs' children included.
    static func usb(_ root: [String: Any]) -> [USBEntry] {
        var found: [USBEntry] = []
        func walk(_ items: [[String: Any]]) {
            for item in items {
                if item["Driver"] == nil, let name = item["_name"] as? String {
                    found.append(USBEntry(name: name, vendor: item["USBDeviceKeyVendorName"] as? String,
                                          vendorID: hex(item["USBDeviceKeyVendorID"]), productID: hex(item["USBDeviceKeyProductID"]),
                                          speed: item["USBDeviceKeyLinkSpeed"] as? String, power: item["USBDeviceKeyPowerAllocation"] as? String))
                }
                walk(item["_items"] as? [[String: Any]] ?? [])
            }
        }
        walk(root["SPUSBHostDataType"] as? [[String: Any]] ?? [])
        return found
    }

    /// One device per thing: Bluetooth entries get their IOKit battery (by
    /// address) and, when that battery says it is on its cable, the USB
    /// entry it is plugged in as (by product id). Connected first, then by name.
    static func merge(bluetooth: [BluetoothEntry], usb: [USBEntry], hid: [HIDBattery]) -> [ConnectedDevice] {
        var unclaimed = usb
        var devices: [ConnectedDevice] = bluetooth.map { entry in
            let match = hid.first { $0.address != nil && $0.address == entry.address }
            var connections: [DeviceConnection] = entry.connected ? [.bluetooth] : []
            var cable: USBEntry?
            if let match, match.transport?.lowercased() == "usb",
               let index = unclaimed.firstIndex(where: { $0.productID != nil && $0.productID == (match.productID ?? entry.productID) }) {
                cable = unclaimed.remove(at: index)
                connections.append(.usb)
            }
            return ConnectedDevice(name: entry.name, kind: entry.kind, connections: connections, isPaired: true,
                                   battery: battery(levels: entry.levels, hid: match), vendor: cable?.vendor,
                                   usbSpeed: cable?.speed, usbPower: cable?.power)
        }
        devices += unclaimed.map {
            ConnectedDevice(name: $0.name, kind: nil, connections: [.usb], isPaired: false, battery: nil,
                            vendor: $0.vendor, usbSpeed: $0.speed, usbPower: $0.power)
        }
        return devices.sorted { ($0.isConnected ? 0 : 1, $0.name.lowercased()) < ($1.isConnected ? 0 : 1, $1.name.lowercased()) }
    }

    static func battery(levels: [String: Int], hid: HIDBattery?) -> DeviceBattery? {
        let single = levels["Main"] ?? levels["Single"] ?? hid?.percent
        guard single != nil || !levels.isEmpty else { return nil }
        return DeviceBattery(percent: single, left: levels["Left"], right: levels["Right"], case: levels["Case"],
                             charging: hid.flatMap { charging(flags: $0.flags) })
    }

    /// The two measured values only.
    static func charging(flags: Int?) -> Bool? {
        switch flags {
        case 3: true
        case 4: false
        default: nil
        }
    }

    /// `"98%"` → 98.
    static func percent(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: number.intValue
        case let text as String: Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
        default: nil
        }
    }

    /// `"0x05ac"` → 1452; a number as itself.
    static func hex(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            let digits = text.lowercased().hasPrefix("0x") ? String(text.dropFirst(2)) : text
            return Int(digits, radix: 16)
        default:
            return nil
        }
    }

    /// `AA-BB-CC-00-00-01` and `aa:bb:cc:00:00:01` alike.
    static func normalisedAddress(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "-", with: ":")
    }
}
