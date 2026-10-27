//
//  ActivityMath.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Rates from two readings, pure: each core's busy share of its ticks, bytes
//  per second from running counters (the kernel's 32-bit interface counters
//  wrap at 4 GiB, so a smaller second reading is a wrap, not a reset), and
//  each process's CPU over the stretch. A process that appeared or ended
//  between the readings is left out: it has no stretch to measure.
//

import Foundation

enum ActivityMath {

    /// Each core's use between two readings, 0–100.
    static func corePercents(_ before: [(busy: UInt64, idle: UInt64)], _ after: [(busy: UInt64, idle: UInt64)]) -> [Double] {
        zip(before, after).map { old, new in
            let busy = Double(new.busy &- old.busy), idle = Double(new.idle &- old.idle)
            return busy + idle > 0 ? (busy / (busy + idle) * 100) : 0
        }
    }

    /// The machine's use: every core's ticks together, 0–100.
    static func totalPercent(_ before: [(busy: UInt64, idle: UInt64)], _ after: [(busy: UInt64, idle: UInt64)]) -> Double {
        let pairs = zip(before, after)
        let busy = pairs.reduce(0.0) { $0 + Double($1.1.busy &- $1.0.busy) }
        let idle = pairs.reduce(0.0) { $0 + Double($1.1.idle &- $1.0.idle) }
        return busy + idle > 0 ? busy / (busy + idle) * 100 : 0
    }

    /// Bytes per second between two readings of a 64-bit counter; a smaller
    /// second reading (a drive ejected, counters reset) is 0, not negative.
    static func rate(_ before: UInt64, _ after: UInt64, seconds: Double) -> Double {
        guard seconds > 0, after >= before else { return 0 }
        return Double(after - before) / seconds
    }

    /// The change in a 32-bit counter that may have wrapped once.
    static func delta32(_ before: UInt32, _ after: UInt32) -> UInt64 {
        after >= before ? UInt64(after - before) : UInt64(after) + (UInt64(UInt32.max) + 1 - UInt64(before))
    }

    /// Bytes received and sent per second, every interface together.
    static func networkRates(_ before: [String: (received: UInt32, sent: UInt32)], _ after: [String: (received: UInt32, sent: UInt32)],
                             seconds: Double) -> (received: Double, sent: Double) {
        guard seconds > 0 else { return (0, 0) }
        var received: UInt64 = 0, sent: UInt64 = 0
        for (name, new) in after {
            guard let old = before[name] else { continue }
            received += delta32(old.received, new.received)
            sent += delta32(old.sent, new.sent)
        }
        return (Double(received) / seconds, Double(sent) / seconds)
    }

    /// The `limit` processes that used the most CPU over the stretch.
    static func top(_ before: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)],
                    _ after: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)],
                    seconds: Double, limit: Int) -> [ProcessActivity] {
        guard seconds > 0 else { return [] }
        let found = after.compactMap { pid, new -> ProcessActivity? in
            guard let old = before[pid], old.name == new.name, new.cpuNanoseconds >= old.cpuNanoseconds else { return nil }
            let percent = Double(new.cpuNanoseconds - old.cpuNanoseconds) / (seconds * 1_000_000_000) * 100
            return ProcessActivity(pid: pid, name: new.name, cpuPercent: (percent * 10).rounded() / 10, memoryBytes: new.memoryBytes)
        }
        return Array(found.sorted { ($0.cpuPercent, $1.pid) > ($1.cpuPercent, $0.pid) }.prefix(limit))
    }
}
