//
//  StorageInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How much room a volume has, told the two ways APFS counts it.
///
/// ``DiskInfo`` lists every volume; this answers for one path — the one a
/// download is about to land on — and adds what the other lacks: the used
/// figure and a `path` so the answer says what it is about.
public struct StorageInfo: Codable, Sendable, Equatable {

    /// The path asked about, e.g. `/` or `/Volumes/Backup`.
    public let path: String

    /// Capacity, in bytes.
    public let totalBytes: Int64

    /// Plain free space, in bytes.
    public let freeBytes: Int64

    /// Free space counting what the system could purge — caches, local
    /// snapshots — if something important needed it. Nil where the
    /// filesystem cannot say.
    public let availableForImportantUsageBytes: Int64?

    /// Total less free, in bytes.
    public let usedBytes: Int64
}
