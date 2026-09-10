//
//  AudioMatching.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Which device a caller means by name.
enum AudioMatching {

    /// An exact name first, then a prefix, then a substring — case-
    /// insensitive — and only when exactly one device fits at that step,
    /// so `Pro` does not pick between `AirPods Pro` and `Pro Display`.
    static func match(_ query: String, in devices: [AudioDevice]) -> AudioDevice? {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        let names = devices.map { $0.name.lowercased() }
        let steps: [(String) -> Bool] = [
            { $0 == needle },
            { $0.hasPrefix(needle) },
            { $0.contains(needle) },
        ]
        for step in steps {
            let hits = zip(devices, names).filter { step($0.1) }.map(\.0)
            if hits.count == 1 { return hits[0] }
            if hits.count > 1 { return nil }
        }
        return nil
    }
}
