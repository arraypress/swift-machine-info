//
//  Machine.swift
//  MachineInfo
//
//  The namespace, and the one-call snapshot of everything.
//

import Foundation

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
