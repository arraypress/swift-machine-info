//
//  ActivationPolicy.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How an app presents itself: in the Dock, in the menu bar only, or not at all.
///
/// AppKit's own three-way split, given stable lowercase words so a JSON
/// consumer can filter on them. `regular` is what a person calls "an app";
/// the other two are what makes `RunningApps.current()` three times longer
/// than the Dock suggests.
public enum ActivationPolicy: String, Codable, Sendable, CaseIterable {

    /// An ordinary app: Dock icon, menu bar, can be frontmost.
    case regular

    /// A menu-bar or background agent with a UI but no Dock icon.
    case accessory

    /// A background process with no UI at all.
    case prohibited
}
