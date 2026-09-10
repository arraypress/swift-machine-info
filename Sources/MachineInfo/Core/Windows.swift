//
//  Windows.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The windows the window server knows about, front to back. Names of
//  other apps' windows need the Screen Recording permission and come back
//  nil without it; everything else is free.
//

import AppKit
import CoreGraphics
import Foundation

/// The windows on this Mac.
public enum Windows {

    /// The front document window — the frontmost app's first ordinary
    /// window, or the first ordinary window on screen when the frontmost
    /// app has none (a menu-bar agent, say).
    ///
    /// Nil when nothing is on screen at all.
    @MainActor
    public static func front() -> WindowInfo? {
        let windows = list(onScreenOnly: true)
        let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return WindowListing.front(of: windows, activePID: activePID)
    }

    /// Every window, front to back, ordinary document windows and the
    /// rest alike — `layer` tells them apart. Desktop elements (the
    /// wallpaper, icons) are always left out.
    ///
    /// Titles are nil without the Screen Recording permission; see
    /// ``WindowInfo/title``.
    public static func list(onScreenOnly: Bool = true) -> [WindowInfo] {
        var options: CGWindowListOption = [.excludeDesktopElements]
        if onScreenOnly { options.insert(.optionOnScreenOnly) } else { options.insert(.optionAll) }
        let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return raw.compactMap(WindowListing.window)
    }
}
