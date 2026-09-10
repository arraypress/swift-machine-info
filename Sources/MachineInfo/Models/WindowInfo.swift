//
//  WindowInfo.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One window known to the window server.
public struct WindowInfo: Codable, Sendable {

    /// The owning app's name, e.g. `Safari`.
    public let ownerName: String

    /// The owning process.
    public let ownerPID: Int32

    /// The window server's number for the window; stable for its lifetime.
    public let windowNumber: Int

    /// The title, when the system will say.
    ///
    /// Nil, not empty, when it is withheld. Since macOS 10.15 the names of
    /// other apps' windows require the Screen Recording permission; without
    /// it the window server simply omits the key, and this reports that
    /// honestly rather than as a window with no title. Measured on macOS 27
    /// without the permission: of 24 windows on screen, the only title that
    /// came back was the window server's own `Menubar`; every application
    /// window's was withheld.
    public let title: String?

    /// The frame, in points.
    public let bounds: WindowBounds

    /// The window level: 0 is an ordinary document window; menus, the Dock
    /// and status items sit higher.
    public let layer: Int

    /// Whether it is currently on screen.
    public let isOnScreen: Bool

    /// A window, for callers building one by hand — a fixture, a test.
    public init(ownerName: String, ownerPID: Int32, windowNumber: Int, title: String?, bounds: WindowBounds,
                layer: Int, isOnScreen: Bool) {
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.windowNumber = windowNumber
        self.title = title
        self.bounds = bounds
        self.layer = layer
        self.isOnScreen = isOnScreen
    }
}
