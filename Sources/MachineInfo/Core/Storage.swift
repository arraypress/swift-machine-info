//
//  Storage.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Free space, for one path.
public enum Storage {

    /// How much room the volume holding `path` has.
    ///
    /// Two free figures because APFS has two truths: plain free space, and
    /// what the system would clear — caches, local Time Machine snapshots —
    /// for something that matters. A download should trust the second; a
    /// "disk almost full" warning should trust the first.
    ///
    /// - Throws: ``MachineInfoError/storageUnreadable(_:)`` when the path is
    ///   not on a readable volume.
    public static func free(at path: String = "/") throws -> StorageInfo {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, total > 0,
              let free = values.volumeAvailableCapacity else {
            throw MachineInfoError.storageUnreadable(path)
        }
        return StorageMath.info(
            path: path,
            total: Int64(total),
            free: Int64(free),
            important: values.volumeAvailableCapacityForImportantUsage
        )
    }
}
