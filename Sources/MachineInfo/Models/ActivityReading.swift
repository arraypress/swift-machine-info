//
//  ActivityReading.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One reading of the machine's running counters — meaningless alone; two
/// of them a moment apart make an ``ActivitySnapshot``.
struct ActivityReading: Sendable, Equatable {
    /// Each core's ticks: busy (user + system + nice) and idle.
    var cores: [(busy: UInt64, idle: UInt64)]
    /// Bytes read and written by the block storage drivers, since boot.
    var diskRead: UInt64
    var diskWrite: UInt64
    /// Bytes received and sent, per interface, as the kernel's 32-bit counters.
    var interfaces: [String: (received: UInt32, sent: UInt32)]
    /// Each readable process: name, CPU time in nanoseconds, footprint.
    var processes: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)]
    /// When it was taken, in seconds of a monotonic clock.
    var time: Double

    static func == (lhs: ActivityReading, rhs: ActivityReading) -> Bool {
        lhs.time == rhs.time && lhs.diskRead == rhs.diskRead && lhs.diskWrite == rhs.diskWrite
            && lhs.cores.map(\.busy) == rhs.cores.map(\.busy) && lhs.cores.map(\.idle) == rhs.cores.map(\.idle)
    }
}
