//
//  DiskInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The mounted volumes and their room. "Available" is reported twice
//  because APFS has two truths: plain free space, and what the system
//  could free by purging caches and snapshots if you actually needed it.
//

import Foundation

/// One mounted volume.
public struct DiskInfo: Codable, Sendable {

    /// The volume's name, e.g. `Macintosh HD`.
    public let name: String
    /// Where it is mounted, e.g. `/` or `/Volumes/Backup`.
    public let mountPoint: String
    /// Capacity, in bytes.
    public let totalBytes: Int64
    /// Plain free space, in bytes.
    public let availableBytes: Int64
    /// Free space counting purgeable content — what important usage could
    /// actually have. `nil` where the filesystem cannot say.
    public let importantAvailableBytes: Int64?
    /// Whether the volume is on an internal device.
    public let isInternal: Bool
    /// Whether the media is removable.
    public let isRemovable: Bool

    /// Every browsable mounted volume.
    public static func mounted() -> [DiskInfo] {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey, .volumeIsRemovableKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys),
                                                         options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  let total = values.volumeTotalCapacity, total > 0 else { return nil }
            return DiskInfo(
                name: values.volumeName ?? url.lastPathComponent,
                mountPoint: url.path,
                totalBytes: Int64(total),
                availableBytes: Int64(values.volumeAvailableCapacity ?? 0),
                importantAvailableBytes: values.volumeAvailableCapacityForImportantUsage,
                isInternal: values.volumeIsInternal ?? false,
                isRemovable: values.volumeIsRemovable ?? false
            )
        }
        .sorted { $0.mountPoint < $1.mountPoint }
    }
}
