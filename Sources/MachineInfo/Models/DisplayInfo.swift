//
//  DisplayInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The screens. Names come from NSScreen — the one public API that knows
//  them — which is main-actor-bound, so everything here is too; pixel
//  sizes and refresh rates come from CoreGraphics against the same
//  display IDs.
//

import AppKit
import CoreGraphics
import Foundation

/// One attached display.
public struct DisplayInfo: Codable, Sendable {

    /// The display's name, e.g. `Odyssey G70D` or `Built-in Display`.
    public let name: String
    /// Width in device pixels.
    public let pixelWidth: Int
    /// Height in device pixels.
    public let pixelHeight: Int
    /// Width in points, as layout sees it.
    public let pointWidth: Int
    /// Height in points.
    public let pointHeight: Int
    /// The backing scale — `2` on Retina panels.
    public let scale: Double
    /// Refresh rate in hertz; `nil` where the mode does not say.
    public let refreshHz: Double?
    /// Whether this is the display with the menu bar.
    public let isMain: Bool

    /// Every attached display.
    @MainActor
    public static func current() -> [DisplayInfo] {
        NSScreen.screens.map { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
                .map { CGDirectDisplayID($0.uint32Value) }
            let mode = id.flatMap { CGDisplayCopyDisplayMode($0) }
            let refresh = mode?.refreshRate
            // CGDisplayPixelsWide answers in LOGICAL pixels on a scaled
            // Retina mode; the mode's pixel size is the panel's truth.
            return DisplayInfo(
                name: screen.localizedName,
                pixelWidth: mode?.pixelWidth ?? Int(screen.frame.width * screen.backingScaleFactor),
                pixelHeight: mode?.pixelHeight ?? Int(screen.frame.height * screen.backingScaleFactor),
                pointWidth: Int(screen.frame.width),
                pointHeight: Int(screen.frame.height),
                scale: Double(screen.backingScaleFactor),
                refreshHz: (refresh ?? 0) > 0 ? refresh : nil,
                isMain: id.map { $0 == CGMainDisplayID() } ?? false
            )
        }
    }
}
