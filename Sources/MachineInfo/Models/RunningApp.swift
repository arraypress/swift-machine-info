//
//  RunningApp.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One running application, as the workspace sees it.
public struct RunningApp: Codable, Sendable {

    /// The name on the Dock or in the menu bar, e.g. `Safari`.
    public let name: String

    /// The bundle identifier, e.g. `com.apple.Safari`; nil for a bare process.
    public let bundleIdentifier: String?

    /// The process identifier.
    public let pid: Int32

    /// Whether it is the frontmost app right now.
    public let isActive: Bool

    /// Whether it is hidden (⌘H), which is not the same as having no windows.
    public let isHidden: Bool

    /// When it launched, where the workspace knows.
    public let launchedAt: Date?

    /// Dock app, menu-bar agent, or background process.
    public let activationPolicy: ActivationPolicy

    /// A running app, for callers building one by hand — a fixture, a test.
    public init(name: String, bundleIdentifier: String?, pid: Int32, isActive: Bool, isHidden: Bool,
                launchedAt: Date?, activationPolicy: ActivationPolicy) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.isActive = isActive
        self.isHidden = isHidden
        self.launchedAt = launchedAt
        self.activationPolicy = activationPolicy
    }
}
