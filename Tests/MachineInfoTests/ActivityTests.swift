//
//  ActivityTests.swift
//  MachineInfoTests
//
//  Created by David Sherlock on 2026.
//
//  Rates from two readings, with no kernel: core shares, counters that
//  wrap, processes that came and went, and one real sample of this Mac
//  checked only for sanity. The readings are invented.
//

import Foundation
import XCTest
@testable import MachineInfo

final class ActivityTests: XCTestCase {

    func testCoresAreTheirBusyShareOfTheirTicks() {
        let before = [(busy: UInt64(100), idle: UInt64(900)), (busy: 0, idle: 0)]
        let after = [(busy: UInt64(400), idle: UInt64(1600)), (busy: 50, idle: 50)]
        XCTAssertEqual(ActivityMath.corePercents(before, after), [30, 50])
        XCTAssertEqual(ActivityMath.totalPercent(before, after), 350.0 / 1100.0 * 100, accuracy: 1e-9,
                       "every core's ticks together, not the mean of the shares")
        XCTAssertEqual(ActivityMath.corePercents([(busy: 5, idle: 5)], [(busy: 5, idle: 5)]), [0], "no ticks is idle, not NaN")
    }

    func testRatesAreBytesPerSecondAndNeverNegative() {
        XCTAssertEqual(ActivityMath.rate(1_000, 3_000, seconds: 2), 1_000)
        XCTAssertEqual(ActivityMath.rate(3_000, 1_000, seconds: 2), 0, "a reset counter is no traffic")
        XCTAssertEqual(ActivityMath.rate(1, 2, seconds: 0), 0)
    }

    func testThirtyTwoBitCountersWrapOnce() {
        XCTAssertEqual(ActivityMath.delta32(10, 30), 20)
        XCTAssertEqual(ActivityMath.delta32(UInt32.max - 9, 10), 20, "past 4 GiB the counter starts again")
        let rates = ActivityMath.networkRates(["en0": (UInt32.max - 99, 0), "gone0": (5, 5)],
                                              ["en0": (100, 400), "new0": (999, 999)], seconds: 2)
        XCTAssertEqual(rates.received, 100, "200 bytes over 2 s; an interface in one reading only counts nothing")
        XCTAssertEqual(rates.sent, 200)
    }

    func testTheBusiestProcessesAreThoseMeasuredAcrossTheStretch() {
        let second: UInt64 = 1_000_000_000
        let before: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)] =
            [1: ("indexer", 10 * second, 100), 2: ("editor", 0, 200), 3: ("reused", 0, 0)]
        let after: [Int32: (name: String, cpuNanoseconds: UInt64, memoryBytes: Int64)] =
            [1: ("indexer", 13 * second, 150), 2: ("editor", second / 2, 250), 3: ("other", 9 * second, 0), 4: ("new", 9 * second, 0)]
        let top = ActivityMath.top(before, after, seconds: 2, limit: 5)
        XCTAssertEqual(top.map(\.name), ["indexer", "editor"], "a pid reused by another program, or a new one, has no stretch")
        XCTAssertEqual(top.first?.cpuPercent, 150, "1.5 cores over 2 s")
        XCTAssertEqual(top.first?.memoryBytes, 150, "memory as it is now")
        XCTAssertEqual(ActivityMath.top(before, after, seconds: 2, limit: 1).count, 1)
    }

    func testARealSampleIsSane() async {
        let snapshot = await SystemActivity.sample(interval: 0.3, top: 3)
        XCTAssertFalse(snapshot.corePercents.isEmpty)
        XCTAssert((0...100).contains(snapshot.cpuPercent))
        XCTAssert(snapshot.corePercents.allSatisfy { (0...100).contains($0) })
        XCTAssertEqual(snapshot.interval, 0.3, accuracy: 0.2)
        XCTAssertLessThanOrEqual(snapshot.top.count, 3)
        XCTAssertEqual(snapshot.load.count, 3)
        XCTAssertNotNil(snapshot.memory)
    }
}
