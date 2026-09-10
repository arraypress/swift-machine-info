//
//  KeepAwake.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Holding the Mac awake for as long as a job needs, and no longer.
//

import Foundation

/// A power assertion: the Mac stays awake while a ``Token`` is alive.
///
/// The same mechanism `caffeinate` uses, without the subprocess. The
/// difference that matters is scope: `caffeinate` holds the machine awake
/// until it is killed, and a script that dies leaves it awake; a token here
/// is released when it goes out of scope, so a crash cannot pin the lid open.
public enum KeepAwake {

    /// Begins holding the Mac awake. Keep the token; drop it to stop.
    ///
    /// By default only idle *system* sleep is prevented, so the display may
    /// still dim and lock — right for a download or a build. Pass
    /// `preventDisplaySleep` for something a person is watching.
    ///
    /// - Parameter reason: What is being kept awake, shown by `pmset -g
    ///   assertions` and Activity Monitor; make it say the job.
    /// - Throws: ``MachineInfoError/assertionFailed(_:)`` with IOKit's code.
    public static func begin(reason: String, preventDisplaySleep: Bool = false) throws -> Token {
        let id = try PowerAssertions.create(reason: reason, display: preventDisplaySleep)
        return Token(id: id, reason: reason, preventsDisplaySleep: preventDisplaySleep)
    }

    /// Runs `body` with the Mac held awake, and releases when it returns
    /// or throws.
    public static func `while`<T>(reason: String, preventDisplaySleep: Bool = false,
                                  _ body: () throws -> T) throws -> T {
        let token = try begin(reason: reason, preventDisplaySleep: preventDisplaySleep)
        defer { token.end() }
        return try body()
    }
}
