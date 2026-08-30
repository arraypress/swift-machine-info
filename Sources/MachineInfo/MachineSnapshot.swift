//
//  MachineSnapshot.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Everything at once: the machine, the system, and how both are doing,
//  as one Codable value an agent can read whole. Main-actor because the
//  display section is (NSScreen owns the names); everything else would
//  run anywhere.
//

import Foundation

/// The whole machine, at one moment.
public struct MachineSnapshot: Codable, Sendable {

    /// What the machine is.
    public let hardware: HardwareInfo
    /// The system and its clock.
    public let os: OSInfo
    /// Memory in use and free; `nil` if Mach refused the statistics.
    public let memory: MemoryStatus?
    /// The mounted, browsable volumes.
    public let disks: [DiskInfo]
    /// The battery, on machines that have one.
    public let battery: BatteryInfo?
    /// The attached displays.
    public let displays: [DisplayInfo]
    /// The running network interfaces.
    public let network: NetworkInfo
    /// When this snapshot was taken.
    public let capturedAt: Date
}

/// The library's front door.
public enum Machine {

    /// Takes a full snapshot. Milliseconds, not seconds — nothing here
    /// launches a process or waits on hardware.
    @MainActor
    public static func snapshot() -> MachineSnapshot {
        MachineSnapshot(
            hardware: .current(),
            os: .current(),
            memory: .current(),
            disks: DiskInfo.mounted(),
            battery: .current(),
            displays: DisplayInfo.current(),
            network: .current(),
            capturedAt: Date()
        )
    }
}
