//
//  StorageMath.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The arithmetic behind ``StorageInfo``.
enum StorageMath {

    /// Assembles the value; used space is total less free, never negative.
    static func info(path: String, total: Int64, free: Int64, important: Int64?) -> StorageInfo {
        StorageInfo(
            path: path,
            totalBytes: total,
            freeBytes: free,
            availableForImportantUsageBytes: important,
            usedBytes: max(0, total - free)
        )
    }

    /// Bytes as people read them: `260.58 GB`.
    static func bytesText(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    /// Percent of the volume in use, rounded; `0` when the total is unknown.
    static func percentUsed(total: Int64, free: Int64) -> Int {
        guard total > 0 else { return 0 }
        return Int(((1 - Double(free) / Double(total)) * 100).rounded())
    }
}
