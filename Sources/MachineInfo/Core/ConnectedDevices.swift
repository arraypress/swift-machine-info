//
//  ConnectedDevices.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Bluetooth and USB devices with their batteries. The one place this
//  library launches a process: AirPods' per-bud and case levels exist only
//  in system_profiler's report (IOBluetooth has them only as private API),
//  so it is asked once for Bluetooth and USB together (~0.1 s). Keyboard,
//  mouse and trackpad levels come from IOKit directly.
//

import Foundation
import IOKit

/// The Bluetooth and USB devices on this Mac.
public enum ConnectedDevices {

    /// Every paired Bluetooth device and every USB device, connected first.
    ///
    /// - Throws: ``MachineInfoError/devicesUnreadable(_:)`` when
    ///   system_profiler cannot be run or answers in a shape not understood.
    public static func all() throws -> [ConnectedDevice] {
        let root = try profilerReport()
        return DeviceDecoding.merge(bluetooth: DeviceDecoding.bluetooth(root), usb: DeviceDecoding.usb(root), hid: hidBatteries())
    }

    /// system_profiler's Bluetooth and USB report, as one JSON object.
    static func profilerReport() throws -> [String: Any] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "SPUSBHostDataType", "-json"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw MachineInfoError.devicesUnreadable("could not run system_profiler: \(error.localizedDescription)") }
        // Read to the end BEFORE waiting: a full pipe would stall it.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { throw MachineInfoError.devicesUnreadable("system_profiler answered in a shape not understood") }
        return root
    }

    /// Keyboard, mouse and trackpad batteries, from the IORegistry.
    static func hidBatteries() -> [HIDBattery] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var found: [HIDBattery] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ name: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            guard let percent = DeviceDecoding.percent(property("BatteryPercent")) else { continue }
            found.append(HIDBattery(address: (property("DeviceAddress") as? String).map(DeviceDecoding.normalisedAddress),
                                    productID: DeviceDecoding.hex(property("ProductID")), transport: property("Transport") as? String,
                                    percent: percent, flags: DeviceDecoding.percent(property("BatteryStatusFlags"))))
        }
        return found
    }
}
