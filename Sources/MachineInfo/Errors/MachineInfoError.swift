//
//  MachineInfoError.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What was refused, in words a caller can print unchanged.
public enum MachineInfoError: Error, LocalizedError, Equatable, Sendable {

    /// No running app matches the bundle identifier or name.
    case notRunning(String)

    /// The process is one this library will not quit: Finder, loginwindow,
    /// or the caller itself.
    case protectedProcess(String)

    /// The power assertion could not be created; carries IOKit's return code.
    case assertionFailed(Int32)

    /// No audio device matches.
    case audioDeviceNotFound(String)

    /// CoreAudio refused; carries its OSStatus.
    case audioError(Int32)

    /// The volume's capacities could not be read at the path.
    case storageUnreadable(String)

    public var errorDescription: String? {
        switch self {
        case .notRunning(let name):
            return "not running: \(name)\nuse the bundle identifier (com.apple.Safari) or the app's name"
        case .protectedProcess(let name):
            return "refusing to quit \(name)\nFinder, loginwindow and this process itself are left alone"
        case .assertionFailed(let code):
            return "could not keep the Mac awake: IOKit returned \(code)"
        case .audioDeviceNotFound(let name):
            return "no audio output device called \(name)"
        case .audioError(let status):
            return "CoreAudio refused: OSStatus \(status)"
        case .storageUnreadable(let path):
            return "no volume capacities readable at \(path)"
        }
    }
}
