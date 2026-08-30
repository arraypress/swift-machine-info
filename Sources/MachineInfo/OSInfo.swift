//
//  OSInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The system: version, build, kernel, and how long it has been up.
//

import Darwin
import Foundation

/// The operating system and its clock.
public struct OSInfo: Codable, Sendable {

    /// Always `macOS` here; the field exists so a snapshot is self-describing.
    public let name: String
    /// The version people say, e.g. `27.0`.
    public let version: String
    /// The build people file bugs against, e.g. `26A5416b`.
    public let build: String
    /// The kernel and its release, e.g. `Darwin 27.0.0`.
    public let kernel: String
    /// Seconds since boot, sleep included.
    public let uptimeSeconds: Double
    /// When the machine booted.
    public let bootedAt: Date?
    /// The thermal pressure right now: `nominal`, `fair`, `serious` or `critical`.
    public let thermalState: String

    /// Reads the system's description.
    public static func current() -> OSInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        return OSInfo(
            name: "macOS",
            version: v.patchVersion == 0 ? "\(v.majorVersion).\(v.minorVersion)" : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            build: Sysctl.string("kern.osversion") ?? "unknown",
            kernel: "\(Sysctl.string("kern.ostype") ?? "Darwin") \(Sysctl.string("kern.osrelease") ?? "?")",
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            bootedAt: Sysctl.bootTime(),
            thermalState: thermal
        )
    }
}
