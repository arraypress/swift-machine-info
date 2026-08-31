//
//  Derivations.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The decision rules the readers apply, separated from the system calls
//  that feed them. A reader touches IOKit or Mach and cannot run in a
//  test; the rule it applies — which sentinel means "no estimate", what
//  pressure level 4 is called, which address is the primary — can, once
//  it lives here alone.
//

import Foundation

/// Pure derivations over values the system readers fetch.
enum Derive {

    /// A power-source minutes estimate, honouring the sentinels: IOKit
    /// reports 0 and -1 for "no estimate", never for a real duration.
    static func batteryMinutes(_ value: Any?) -> Int? {
        guard let minutes = value as? Int, minutes > 0 else { return nil }
        return minutes
    }

    /// Full-charge capacity against design capacity, as a rounded percent.
    static func healthPercent(design: Int?, max: Int?) -> Int? {
        guard let design, design > 0, let max else { return nil }
        return Int((Double(max) / Double(design) * 100).rounded())
    }

    /// The kernel's memory-pressure level, in the words Activity Monitor
    /// uses. 1, 2 and 4 are the only levels the kernel defines.
    static func pressureLabel(_ level: Int64?) -> String? {
        switch level {
        case 1: return "normal"
        case 2: return "warning"
        case 4: return "critical"
        default: return nil
        }
    }

    /// The version people say: the patch is dropped when it is zero.
    static func versionString(_ major: Int, _ minor: Int, _ patch: Int) -> String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }

    /// The thermal pressure, as a stable lowercase word.
    static func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    /// An interface address fit for a report: link-local IPv6 is noise
    /// (`nil`), and a scope suffix (`%en0`) is stripped.
    static func cleanAddress(_ raw: String) -> String? {
        if raw.hasPrefix("fe80") { return nil }
        if let percent = raw.firstIndex(of: "%") { return String(raw[..<percent]) }
        return raw
    }

    /// The address that looks like the primary route out — the first
    /// non-loopback IPv4 on an `en` interface.
    static func primary(
        of addresses: [(name: String, address: String, family: String)]
    ) -> (name: String, address: String, family: String)? {
        addresses.first { $0.family == "IPv4" && $0.name.hasPrefix("en") }
    }
}
