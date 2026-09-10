//
//  RunningApps.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The apps that are running, and the one in front — read from the
//  workspace, which knows every launched application whether or not it
//  has a Dock icon.
//

import AppKit
import Foundation

/// The running applications.
public enum RunningApps {

    /// Every running application, Dock apps first, then menu-bar agents,
    /// then background processes, each group by name.
    ///
    /// Three times as many as the Dock shows, because the workspace counts
    /// agents and helpers too; filter on ``RunningApp/activationPolicy`` for
    /// the ones a person would call apps.
    @MainActor
    public static func current() -> [RunningApp] {
        NSWorkspace.shared.runningApplications
            .map(AppReading.app)
            .sorted(by: AppReading.order)
    }

    /// The frontmost application, or nil when nothing has focus — a
    /// headless session, or the moment between two apps.
    @MainActor
    public static func frontmost() -> RunningApp? {
        NSWorkspace.shared.frontmostApplication.map(AppReading.app)
    }

    /// Asks an app to quit, by bundle identifier or by name.
    ///
    /// Politely by default — the app gets its "save changes?" moment and may
    /// refuse — and `force` kills it the way Force Quit does, unsaved work
    /// and all. Finder, loginwindow and the calling process are refused
    /// outright: quitting them is how a session ends, not how an app closes.
    /// Returns whether the request was delivered; the app may still be
    /// running a moment later while it winds down.
    ///
    /// - Throws: ``MachineInfoError/notRunning(_:)`` when nothing matches,
    ///   ``MachineInfoError/protectedProcess(_:)`` for the three above.
    @MainActor
    @discardableResult
    public static func quit(_ bundleIdentifierOrName: String, force: Bool = false) throws -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        guard let app = AppReading.match(bundleIdentifierOrName, in: apps) else {
            throw MachineInfoError.notRunning(bundleIdentifierOrName)
        }
        let name = app.localizedName ?? bundleIdentifierOrName
        if ProtectedProcesses.isProtected(bundleIdentifier: app.bundleIdentifier, pid: app.processIdentifier) {
            throw MachineInfoError.protectedProcess(name)
        }
        return force ? app.forceTerminate() : app.terminate()
    }
}
