//
//  BatteryInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The battery, from two places that each know half the story: the power
//  sources API for charge and time estimates, and the smart-battery
//  service in the IORegistry for cycles and health. Desktops get `nil`.
//

import Foundation
import IOKit
import IOKit.ps

/// The battery, if the machine has one.
public struct BatteryInfo: Codable, Sendable {

    /// Charge, 0–100.
    public let percentage: Int
    /// Whether it is charging right now.
    public let isCharging: Bool
    /// Whether external power is connected (full and plugged in is
    /// `true` here and `false` above).
    public let externalPower: Bool
    /// Charge cycles so far, where the smart battery reports them.
    public let cycleCount: Int?
    /// Current full-charge capacity against the design capacity, 0–100.
    public let healthPercent: Int?
    /// Minutes until empty at the current draw; `nil` while unknown.
    public let timeToEmptyMinutes: Int?
    /// Minutes until full while charging; `nil` while unknown.
    public let timeToFullMinutes: Int?

    /// Reads the battery, or `nil` on a machine without one.
    public static func current() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let smart = smartBattery()
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let external = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let minutes: (Any?) -> Int? = { value in
                guard let m = value as? Int, m > 0 else { return nil }  // 0 and -1 both mean "no estimate"
                return m
            }
            return BatteryInfo(
                percentage: description[kIOPSCurrentCapacityKey] as? Int ?? 0,
                isCharging: charging,
                externalPower: external,
                cycleCount: smart?.cycles,
                healthPercent: smart?.health,
                timeToEmptyMinutes: external ? nil : minutes(description[kIOPSTimeToEmptyKey]),
                timeToFullMinutes: charging ? minutes(description[kIOPSTimeToFullChargeKey]) : nil
            )
        }
        return nil
    }

    /// Cycle count and health from the `AppleSmartBattery` service.
    private static func smartBattery() -> (cycles: Int?, health: Int?)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ name: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }
        let cycles = property("CycleCount")
        var health: Int?
        if let design = property("DesignCapacity"), design > 0,
           let max = property("AppleRawMaxCapacity") ?? property("MaxCapacity") {
            health = Int((Double(max) / Double(design) * 100).rounded())
        }
        return (cycles, health)
    }
}
