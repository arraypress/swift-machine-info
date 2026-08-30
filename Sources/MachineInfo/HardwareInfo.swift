//
//  HardwareInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  What this Mac is: the model, the chip, the cores, the memory. Identity
//  without a serial number — nothing here can name one machine among
//  identical ones, which is deliberate.
//

import Darwin
import Foundation
import IOKit

/// The machine itself.
public struct HardwareInfo: Codable, Sendable {

    /// The model identifier, e.g. `Mac15,10`.
    public let modelIdentifier: String
    /// The name on the box, e.g. `MacBook Pro (16-inch, Nov 2023)`, read
    /// from the device tree. Absent on Intel Macs, which do not carry it.
    public let productName: String?
    /// The CPU's own name, e.g. `Apple M3 Max`.
    public let chip: String
    /// The instruction set, e.g. `arm64`.
    public let architecture: String
    /// Logical cores in all.
    public let coreCount: Int
    /// Performance cores, where the chip distinguishes them.
    public let performanceCores: Int?
    /// Efficiency cores, where the chip distinguishes them.
    public let efficiencyCores: Int?
    /// Installed memory, in bytes.
    public let memoryBytes: Int64
    /// The Bonjour-ish host name, e.g. `Davids-MacBook-Pro.local`.
    public let hostName: String

    /// Reads the machine's description from sysctl and the device tree.
    public static func current() -> HardwareInfo {
        HardwareInfo(
            modelIdentifier: Sysctl.string("hw.model") ?? Sysctl.string("hw.product") ?? "unknown",
            productName: deviceTreeProductName(),
            chip: Sysctl.string("machdep.cpu.brand_string") ?? "unknown",
            architecture: Sysctl.string("hw.machine") ?? "unknown",
            coreCount: Int(Sysctl.integer("hw.logicalcpu") ?? 0),
            performanceCores: Sysctl.integer("hw.perflevel0.physicalcpu").map(Int.init),
            efficiencyCores: Sysctl.integer("hw.perflevel1.physicalcpu").map(Int.init),
            memoryBytes: Sysctl.integer("hw.memsize") ?? 0,
            hostName: ProcessInfo.processInfo.hostName
        )
    }

    /// Apple Silicon carries the marketing name in the device tree's
    /// `product` node; Intel Macs do not, and get `nil` rather than a
    /// maintained lookup table that would age badly.
    private static func deviceTreeProductName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(entry) }
        guard let value = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        // The device tree stores a NUL-terminated C string.
        let trimmed = value.prefix { $0 != 0 }
        return trimmed.isEmpty ? nil : String(decoding: trimmed, as: UTF8.self)
    }
}
