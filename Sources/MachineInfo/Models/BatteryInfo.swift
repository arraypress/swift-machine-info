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
    /// Maximum capacity, 0–100 — **the figure System Settings shows**.
    ///
    /// Read from macOS rather than computed, and the difference is not
    /// academic. On this machine the registry reports a design capacity of
    /// 6249 mAh and a full-charge capacity of 4928, which is 78.9%; the
    /// nominal charge capacity gives 81.3%; System Settings says **84%**.
    /// Apple's number is smoothed and calibrated in a way no public arithmetic
    /// reproduces, and a tool that prints 79 next to Apple's 84 is a tool
    /// nobody believes twice.
    public let healthPercent: Int?

    /// Apple's own word for the battery's state — `Normal`, `Service
    /// Recommended`, and so on.
    public let condition: String?

    /// Design capacity in mAh, where the battery reports it.
    public let designCapacity: Int?

    /// What a full charge holds today, in mAh.
    public let fullChargeCapacity: Int?

    /// Battery temperature in Celsius.
    public let temperatureCelsius: Double?
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
            let reported = systemReported()
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let external = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return BatteryInfo(
                percentage: description[kIOPSCurrentCapacityKey] as? Int ?? 0,
                isCharging: charging,
                externalPower: external,
                cycleCount: smart?.cycles,
                healthPercent: reported?.maximumCapacity,
                condition: reported?.condition,
                designCapacity: smart?.design,
                fullChargeCapacity: smart?.fullCharge,
                temperatureCelsius: smart?.temperature,
                timeToEmptyMinutes: external ? nil : Derive.batteryMinutes(description[kIOPSTimeToEmptyKey]),
                timeToFullMinutes: charging ? Derive.batteryMinutes(description[kIOPSTimeToFullChargeKey]) : nil
            )
        }
        return nil
    }

    /// Cycles, capacities and temperature from the `AppleSmartBattery`
    /// service.
    ///
    /// The capacities are read from the nested `BatteryData` dictionary, not
    /// from the top level, and that was the bug this replaces. On Apple
    /// silicon `DesignCapacity` **does not exist** as a top-level key — it
    /// lives inside `BatteryData` — so the old read returned nil and health
    /// was silently absent from every report.
    ///
    /// Worse than absent, had it found one: the top-level `MaxCapacity` is
    /// **100**. It is a PERCENTAGE, not a capacity in mAh, so dividing a
    /// design capacity by it would have produced 6249% and looked like a
    /// units bug rather than a missing key.
    private static func smartBattery() -> (cycles: Int?, design: Int?, fullCharge: Int?, temperature: Double?)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        func property(_ name: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }
        let data = property("BatteryData") as? [String: Any]

        /// Reported in hundredths of a degree.
        let temperature = (property("Temperature") as? Int).map { Double($0) / 100 }

        return (
            cycles: property("CycleCount") as? Int ?? data?["CycleCount"] as? Int,
            design: data?["DesignCapacity"] as? Int,
            fullCharge: data?["FullChargeCapacity"] as? Int,
            temperature: temperature
        )
    }

    /// Maximum capacity and condition, as macOS itself reports them.
    ///
    /// A subprocess in a library that is otherwise pure IOKit, which is a real
    /// cost and worth the reason: this is the only place Apple's own figure is
    /// available. Every arithmetic on the registry's capacities lands several
    /// points away from what System Settings shows, and being consistent with
    /// the machine matters more here than being pure. Measured at 146 ms, and
    /// only on the battery path.
    private static func systemReported() -> (maximumCapacity: Int?, condition: String?)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-xml"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let plist = try? PropertyListSerialization.propertyList(from: output, format: nil),
              let entries = plist as? [[String: Any]],
              let items = entries.first?["_items"] as? [[String: Any]],
              let health = items.first?["sppower_battery_health_info"] as? [String: Any] else { return nil }

        /// Apple hands this back as "84%", so the sign comes off before it is
        /// a number.
        let capacity = (health["sppower_battery_health_maximum_capacity"] as? String)
            .map { $0.replacingOccurrences(of: "%", with: "") }
            .flatMap(Int.init)

        return (capacity, health["sppower_battery_health"] as? String)
    }
}
