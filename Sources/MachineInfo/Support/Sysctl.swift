//
//  Sysctl.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The kernel's answers, typed. Everything here is a read of sysctlbyname —
//  no processes spawned, no parsing of `system_profiler` output, which is
//  what keeps a full snapshot in milliseconds rather than seconds.
//

import Darwin
import Foundation

enum Sysctl {

    /// The string value of a sysctl name, or `nil` where the kernel has none.
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    /// The integer value of a sysctl name, whatever width the kernel uses.
    static func integer(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname(name, &value, &size, nil, 0) == 0 {
            // A 4-byte answer arrives in the low half.
            return size == 4 ? Int64(Int32(truncatingIfNeeded: value)) : value
        }
        return nil
    }

    /// When the kernel booted — `kern.boottime` as a date.
    static func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0, tv.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }
}
