//
//  ProtectedProcesses.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The processes ``RunningApps/quit(_:force:)`` will not touch.
enum ProtectedProcesses {

    /// Finder and loginwindow end the session rather than an app; the caller
    /// itself is refused because a tool that quits itself mid-answer
    /// reports nothing.
    static let bundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.loginwindow",
    ]

    /// Whether a process is off limits.
    static func isProtected(bundleIdentifier: String?, pid: Int32,
                            ownPID: Int32 = ProcessInfo.processInfo.processIdentifier) -> Bool {
        if pid == ownPID { return true }
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier.lowercased())
    }
}
