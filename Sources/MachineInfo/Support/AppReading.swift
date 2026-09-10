//
//  AppReading.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  From NSRunningApplication to a value, and the rules for ordering and
//  matching — the parts a test can hold without a workspace.
//

import AppKit
import Foundation

/// Reading and ranking running applications.
enum AppReading {

    /// One workspace entry as a value.
    static func app(_ application: NSRunningApplication) -> RunningApp {
        RunningApp(
            name: application.localizedName ?? application.bundleIdentifier ?? "pid \(application.processIdentifier)",
            bundleIdentifier: application.bundleIdentifier,
            pid: application.processIdentifier,
            isActive: application.isActive,
            isHidden: application.isHidden,
            launchedAt: application.launchDate,
            activationPolicy: policy(application.activationPolicy)
        )
    }

    /// AppKit's policy as the library's word.
    static func policy(_ policy: NSApplication.ActivationPolicy) -> ActivationPolicy {
        switch policy {
        case .regular: return .regular
        case .accessory: return .accessory
        case .prohibited: return .prohibited
        @unknown default: return .prohibited
        }
    }

    /// Dock apps first, then agents, then background processes; by name
    /// within each group, case-insensitively.
    static func order(_ a: RunningApp, _ b: RunningApp) -> Bool {
        if a.activationPolicy != b.activationPolicy {
            return rank(a.activationPolicy) < rank(b.activationPolicy)
        }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }

    /// The app a caller means: an exact bundle identifier first, then an
    /// exact name, then a name prefix — case-insensitive throughout, and
    /// `regular` apps ahead of agents when a name is shared.
    static func match(_ query: String, in apps: [NSRunningApplication]) -> NSRunningApplication? {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        let ranked = apps.sorted { rank(policy($0.activationPolicy)) < rank(policy($1.activationPolicy)) }
        if let exact = ranked.first(where: { $0.bundleIdentifier?.lowercased() == needle }) { return exact }
        if let named = ranked.first(where: { $0.localizedName?.lowercased() == needle }) { return named }
        return ranked.first { $0.localizedName?.lowercased().hasPrefix(needle) == true }
    }

    private static func rank(_ policy: ActivationPolicy) -> Int {
        switch policy {
        case .regular: 0
        case .accessory: 1
        case .prohibited: 2
        }
    }
}
