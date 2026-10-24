//
//  ConnectedDevicesTests.swift
//  MachineInfoTests
//
//  Created by David Sherlock on 2026.
//
//  system_profiler's report and IOKit's battery entries in their measured
//  shapes; every name, address and id invented.
//

import Foundation
import XCTest
@testable import MachineInfo

final class ConnectedDevicesTests: XCTestCase {

    /// Earbuds (three levels), a keyboard charging on its cable, a mouse that
    /// is off, a USB stick behind a hub.
    nonisolated(unsafe) static let report: [String: Any] = [
        "SPBluetoothDataType": [[
            "controller_properties": ["controller_state": "attrib_on"],
            "device_connected": [
                ["Test Buds": ["device_address": "AA:BB:CC:00:00:01", "device_minorType": "Headphones", "device_productID": "0x2027",
                               "device_batteryLevelLeft": "80%", "device_batteryLevelRight": "75%", "device_batteryLevelCase": "40%"]],
            ],
            "device_not_connected": [
                ["Test Keyboard": ["device_address": "AA:BB:CC:00:00:02", "device_minorType": "Keyboard", "device_productID": "0x0321"]],
                ["Test Mouse": ["device_address": "AA:BB:CC:00:00:03", "device_minorType": "Mouse", "device_productID": "0x0323"]],
            ],
        ]],
        "SPUSBHostDataType": [
            ["_name": "USB 3.1 Bus", "Driver": "AppleT8122USBXHCI", "_items": [
                ["_name": "Test Keyboard", "USBDeviceKeyVendorName": "Apple Inc.", "USBDeviceKeyVendorID": "0x05ac",
                 "USBDeviceKeyProductID": "0x0321", "USBDeviceKeyLinkSpeed": "12 Mb/s", "USBDeviceKeyPowerAllocation": "2.5 W (500 mA)",
                 "USBDeviceKeySerialNumber": "NOT-KEPT"],
                ["_name": "Test Hub", "USBDeviceKeyProductID": "0x0610", "_items": [
                    ["_name": "Test Stick", "USBDeviceKeyVendorName": "Example Corp", "USBDeviceKeyProductID": "0x1000", "USBDeviceKeyLinkSpeed": "5 Gb/s"],
                ]],
            ]],
            ["_name": "USB 3.1 Bus", "Driver": "AppleT8122USBXHCI"],
        ],
    ]

    static let hid = [
        HIDBattery(address: "aa:bb:cc:00:00:02", productID: 0x0321, transport: "USB", percent: 61, flags: 3),
        HIDBattery(address: "aa:bb:cc:00:00:09", productID: 0x0999, transport: "Bluetooth", percent: 50, flags: 4),
    ]

    func testEntriesAreRead() {
        let bluetooth = DeviceDecoding.bluetooth(Self.report)
        XCTAssertEqual(bluetooth.map(\.name), ["Test Buds", "Test Keyboard", "Test Mouse"])
        XCTAssertEqual(bluetooth[0].levels, ["Left": 80, "Right": 75, "Case": 40])
        XCTAssertEqual(bluetooth[1].address, "aa:bb:cc:00:00:02")
        XCTAssertEqual(bluetooth[1].productID, 0x0321)
        XCTAssertEqual(bluetooth.map(\.connected), [true, false, false])
        let usb = DeviceDecoding.usb(Self.report)
        XCTAssertEqual(usb.map(\.name), ["Test Keyboard", "Test Hub", "Test Stick"])
        XCTAssertEqual(usb[0].vendorID, 0x05ac)
    }

    func testOneDevicePerThing() {
        let devices = DeviceDecoding.merge(bluetooth: DeviceDecoding.bluetooth(Self.report), usb: DeviceDecoding.usb(Self.report), hid: Self.hid)
        XCTAssertEqual(devices.map(\.name), ["Test Buds", "Test Hub", "Test Keyboard", "Test Stick", "Test Mouse"])
        let buds = devices[0]
        XCTAssertEqual(buds.connections, [.bluetooth])
        XCTAssertEqual(buds.battery, DeviceBattery(percent: nil, left: 80, right: 75, case: 40, charging: nil))
        XCTAssertEqual(buds.battery?.lowest, 75)
        // The keyboard on its cable: one device, USB, charging, its IOKit level.
        let keyboard = devices[2]
        XCTAssertEqual(keyboard.connections, [.usb])
        XCTAssertTrue(keyboard.isPaired)
        XCTAssertEqual(keyboard.battery, DeviceBattery(percent: 61, left: nil, right: nil, case: nil, charging: true))
        XCTAssertEqual(keyboard.usbSpeed, "12 Mb/s")
        XCTAssertEqual(keyboard.vendor, "Apple Inc.")
        XCTAssertEqual(devices[3].connections, [.usb])
        XCTAssertFalse(devices[3].isPaired)
        XCTAssertFalse(devices[4].isConnected)
        XCTAssertNil(devices[4].battery)
        // Nothing carries a serial number or an address.
        let json = String(decoding: try! JSONEncoder().encode(devices), as: UTF8.self)
        XCTAssertFalse(json.contains("NOT-KEPT"))
        XCTAssertFalse(json.lowercased().contains("aa:bb:cc"))
    }

    func testFlagsAndText() {
        XCTAssertEqual(DeviceDecoding.charging(flags: 3), true)
        XCTAssertEqual(DeviceDecoding.charging(flags: 4), false)
        XCTAssertNil(DeviceDecoding.charging(flags: 1))
        XCTAssertNil(DeviceDecoding.charging(flags: nil))
        XCTAssertEqual(DeviceDecoding.percent("98%"), 98)
        XCTAssertEqual(DeviceDecoding.percent(NSNumber(value: 7)), 7)
        XCTAssertNil(DeviceDecoding.percent("n/a"))
        XCTAssertEqual(DeviceDecoding.hex("0x05AC"), 1452)
        XCTAssertEqual(DeviceDecoding.hex(NSNumber(value: 801)), 801)
        XCTAssertEqual(DeviceDecoding.normalisedAddress("AA-BB-CC-00-00-01"), "aa:bb:cc:00:00:01")
    }

    func testABluetoothDeviceOnBatteryIsNotCharging() {
        let entry = BluetoothEntry(name: "Test Trackpad", address: "aa:bb:cc:00:00:09", kind: "trackpad", connected: true, productID: 0x0999, levels: [:])
        let devices = DeviceDecoding.merge(bluetooth: [entry], usb: [], hid: Self.hid)
        XCTAssertEqual(devices[0].battery, DeviceBattery(percent: 50, left: nil, right: nil, case: nil, charging: false))
        XCTAssertEqual(devices[0].connections, [.bluetooth])
    }

    /// The real report on this Mac: it runs and decodes, whatever is paired.
    func testTheRealReportDecodes() throws {
        let root = try ConnectedDevices.profilerReport()
        XCTAssertNotNil(root["SPBluetoothDataType"])
        XCTAssertNotNil(root["SPUSBHostDataType"])
        _ = try ConnectedDevices.all()
    }
}
