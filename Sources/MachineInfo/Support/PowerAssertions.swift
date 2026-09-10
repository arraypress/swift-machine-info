//
//  PowerAssertions.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation
import IOKit
import IOKit.pwr_mgt

/// The IOKit calls behind ``KeepAwake``.
enum PowerAssertions {

    /// Creates an assertion and returns its identifier.
    static func create(reason: String, display: Bool) throws -> UInt32 {
        let type = display ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        guard status == kIOReturnSuccess else { throw MachineInfoError.assertionFailed(status) }
        return id
    }

    /// Releases an assertion; releasing twice is harmless to IOKit but the
    /// token guards against it anyway.
    static func release(_ id: UInt32) {
        IOPMAssertionRelease(id)
    }
}
