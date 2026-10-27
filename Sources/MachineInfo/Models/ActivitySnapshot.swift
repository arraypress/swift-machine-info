//
//  ActivitySnapshot.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What the machine is doing: two readings a moment apart, and the rates
/// between them, with the state that needs no rate (memory, battery,
/// thermal state) read at the end.
public struct ActivitySnapshot: Sendable, Codable {
    /// CPU in use across every core, 0–100.
    public let cpuPercent: Double
    /// Each core's use, 0–100, in the kernel's order.
    public let corePercents: [Double]
    /// Load averages over 1, 5 and 15 minutes.
    public let load: [Double]
    /// Memory, with the kernel's own pressure level.
    public let memory: MemoryStatus?
    /// Bytes read from the internal and attached drives, per second.
    public let diskReadPerSecond: Double
    /// Bytes written to them, per second.
    public let diskWritePerSecond: Double
    /// Bytes received on every network interface but loopback, per second.
    public let networkInPerSecond: Double
    /// Bytes sent on them, per second.
    public let networkOutPerSecond: Double
    /// The processes using the most CPU over the sample, most first — only
    /// those this user may read: root's processes are not visible without root.
    public let top: [ProcessActivity]
    /// The OS's thermal state: nominal, fair, serious or critical.
    public let thermalState: String
    /// Seconds since boot.
    public let uptimeSeconds: Double
    /// The battery, on a Mac that has one.
    public let battery: BatteryInfo?
    /// How long the sample was, in seconds.
    public let interval: Double
    /// When it ended.
    public let capturedAt: Date

    /// A snapshot.
    public init(cpuPercent: Double, corePercents: [Double], load: [Double], memory: MemoryStatus?, diskReadPerSecond: Double,
                diskWritePerSecond: Double, networkInPerSecond: Double, networkOutPerSecond: Double, top: [ProcessActivity],
                thermalState: String, uptimeSeconds: Double, battery: BatteryInfo?, interval: Double, capturedAt: Date) {
        self.cpuPercent = cpuPercent
        self.corePercents = corePercents
        self.load = load
        self.memory = memory
        self.diskReadPerSecond = diskReadPerSecond
        self.diskWritePerSecond = diskWritePerSecond
        self.networkInPerSecond = networkInPerSecond
        self.networkOutPerSecond = networkOutPerSecond
        self.top = top
        self.thermalState = thermalState
        self.uptimeSeconds = uptimeSeconds
        self.battery = battery
        self.interval = interval
        self.capturedAt = capturedAt
    }
}
