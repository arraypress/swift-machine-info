//
//  WindowListing.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  From the window server's dictionaries to values, and the rule for which
//  window is "the front one" — testable with dictionaries made by hand.
//

import CoreGraphics
import Foundation

/// Reading the window list.
enum WindowListing {

    /// One window-server dictionary as a value; nil when it lacks the
    /// owner, number or bounds every real window carries.
    static func window(_ entry: [String: Any]) -> WindowInfo? {
        guard let owner = entry[kCGWindowOwnerName as String] as? String,
              let pid = entry[kCGWindowOwnerPID as String] as? Int32 ?? (entry[kCGWindowOwnerPID as String] as? Int).map(Int32.init),
              let number = entry[kCGWindowNumber as String] as? Int,
              let boundsDictionary = entry[kCGWindowBounds as String] as? [String: Any],
              let bounds = bounds(boundsDictionary) else { return nil }
        // Absent means withheld (no Screen Recording permission) or an app
        // that never named the window; either way there is no title to give.
        let title = (entry[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return WindowInfo(
            ownerName: owner,
            ownerPID: pid,
            windowNumber: number,
            title: title,
            bounds: bounds,
            layer: entry[kCGWindowLayer as String] as? Int ?? 0,
            isOnScreen: (entry[kCGWindowIsOnscreen as String] as? Bool) ?? ((entry[kCGWindowIsOnscreen as String] as? Int) == 1)
        )
    }

    /// `{X, Y, Width, Height}` as bounds; nil if any is missing.
    static func bounds(_ dictionary: [String: Any]) -> WindowBounds? {
        func number(_ key: String) -> Double? {
            (dictionary[key] as? Double) ?? (dictionary[key] as? Int).map(Double.init)
        }
        guard let x = number("X"), let y = number("Y"), let width = number("Width"), let height = number("Height") else {
            return nil
        }
        return WindowBounds(x: x, y: y, width: width, height: height)
    }

    /// The front document window: the first ordinary (layer 0) window
    /// belonging to the active app, else the first ordinary window at all.
    static func front(of windows: [WindowInfo], activePID: Int32?) -> WindowInfo? {
        let ordinary = windows.filter { $0.layer == 0 }
        if let activePID, let own = ordinary.first(where: { $0.ownerPID == activePID }) { return own }
        return ordinary.first
    }
}
