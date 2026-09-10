//
//  KeepAwake+Token.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension KeepAwake {

    /// A held assertion. Ends when ``end()`` is called or when the token is
    /// deallocated, whichever comes first, and only once.
    public final class Token: @unchecked Sendable {

        /// What was given as the reason.
        public let reason: String

        /// Whether the display is being held on as well.
        public let preventsDisplaySleep: Bool

        /// Whether the assertion is still held.
        public private(set) var isActive: Bool

        private var assertionID: UInt32
        private let lock = NSLock()

        init(id: UInt32, reason: String, preventsDisplaySleep: Bool) {
            assertionID = id
            self.reason = reason
            self.preventsDisplaySleep = preventsDisplaySleep
            isActive = true
        }

        /// Lets the Mac sleep again. Safe to call twice.
        public func end() {
            lock.lock()
            defer { lock.unlock() }
            guard isActive else { return }
            PowerAssertions.release(assertionID)
            isActive = false
        }

        deinit { end() }
    }
}
