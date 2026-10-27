//
//  SystemActivity.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  What the machine is doing now: two readings `interval` apart and the
//  rates between them (ActivityMath), with memory, battery, thermal state
//  and uptime read at the end. For a terminal dashboard or an agent's
//  question ("why is the Mac slow?"), not a menu-bar app.
//

import Darwin
import Foundation

/// The machine's activity over a short sample.
public enum SystemActivity {

    /// Samples the machine.
    ///
    /// - Parameters:
    ///   - interval: Seconds between the two readings; longer is steadier.
    ///   - top: How many of the busiest processes to report.
    /// - Returns: The rates over the sample and the state at its end.
    public static func sample(interval: Double = 1, top: Int = 5) async -> ActivitySnapshot {
        let before = ActivityReader.read()
        try? await Task.sleep(nanoseconds: UInt64(max(0.1, interval) * 1_000_000_000))
        let after = ActivityReader.read()
        return snapshot(before, after, top: top)
    }

    /// The snapshot two readings make.
    static func snapshot(_ before: ActivityReading, _ after: ActivityReading, top: Int, now: Date = Date()) -> ActivitySnapshot {
        let seconds = after.time - before.time
        var loads = [Double](repeating: 0, count: 3)
        let gotLoad = getloadavg(&loads, 3) == 3
        let network = ActivityMath.networkRates(before.interfaces, after.interfaces, seconds: seconds)
        let os = OSInfo.current()
        return ActivitySnapshot(
            cpuPercent: (ActivityMath.totalPercent(before.cores, after.cores) * 10).rounded() / 10,
            corePercents: ActivityMath.corePercents(before.cores, after.cores).map { ($0 * 10).rounded() / 10 },
            load: gotLoad ? loads.map { ($0 * 100).rounded() / 100 } : [],
            memory: .current(),
            diskReadPerSecond: ActivityMath.rate(before.diskRead, after.diskRead, seconds: seconds),
            diskWritePerSecond: ActivityMath.rate(before.diskWrite, after.diskWrite, seconds: seconds),
            networkInPerSecond: network.received, networkOutPerSecond: network.sent,
            top: ActivityMath.top(before.processes, after.processes, seconds: seconds, limit: top),
            thermalState: os.thermalState, uptimeSeconds: os.uptimeSeconds, battery: .current(),
            interval: (seconds * 1000).rounded() / 1000, capturedAt: now)
    }
}
