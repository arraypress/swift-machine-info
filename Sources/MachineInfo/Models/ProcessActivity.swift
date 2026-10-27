//
//  ProcessActivity.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One process's share of the machine over a sample.
public struct ProcessActivity: Sendable, Codable, Equatable {
    /// Its process id.
    public let pid: Int32
    /// Its name, as the kernel knows it.
    public let name: String
    /// CPU used over the sample, as a percentage of one core (a process using
    /// two cores fully reads 200).
    public let cpuPercent: Double
    /// Memory it accounts for, in bytes (its physical footprint).
    public let memoryBytes: Int64

    /// A process's activity.
    public init(pid: Int32, name: String, cpuPercent: Double, memoryBytes: Int64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}
