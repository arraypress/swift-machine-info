//
//  MachineInfoTests.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  Run on a real Mac, these assert the snapshot describes it sensibly —
//  a Mac with no cores or an empty root volume is a read gone wrong,
//  not a strange machine.
//

import Foundation
import XCTest
@testable import MachineInfo

final class MachineInfoTests: XCTestCase {

    func testHardwareDescribesARealMac() {
        let hw = HardwareInfo.current()
        XCTAssertTrue(hw.modelIdentifier.contains("Mac"), hw.modelIdentifier)
        XCTAssertGreaterThanOrEqual(hw.coreCount, 2)
        XCTAssertGreaterThan(hw.memoryBytes, 4 << 30, "less than 4 GB of RAM read back")
        XCTAssertFalse(hw.chip.isEmpty)
        if hw.architecture == "arm64" {
            XCTAssertNotNil(hw.performanceCores, "Apple Silicon reports its core mix")
        }
    }

    func testOSAndUptimeAreSane() {
        let os = OSInfo.current()
        XCTAssertGreaterThanOrEqual(Int(os.version.split(separator: ".")[0])!, 14)
        XCTAssertFalse(os.build.isEmpty)
        XCTAssertGreaterThan(os.uptimeSeconds, 1)
        if let booted = os.bootedAt {
            XCTAssertLessThan(booted, Date())
        }
    }

    func testMemoryAddsUpToSomething() throws {
        let memory = try XCTUnwrap(MemoryStatus.current())
        XCTAssertGreaterThan(memory.totalBytes, 4 << 30)
        XCTAssertGreaterThan(memory.freeBytes + memory.activeBytes + memory.wiredBytes, 0)
    }

    func testRootVolumeIsPresent() {
        let disks = DiskInfo.mounted()
        let root = disks.first { $0.mountPoint == "/" }
        XCTAssertNotNil(root, "\(disks.map(\.mountPoint))")
        XCTAssertGreaterThan(root!.totalBytes, 50 << 30)
        XCTAssertGreaterThan(root!.availableBytes, 0)
        XCTAssertLessThanOrEqual(root!.availableBytes, root!.totalBytes)
    }

    func testBatteryIsCoherentWhenPresent() {
        guard let battery = BatteryInfo.current() else { return }  // desktops
        XCTAssertTrue((0...100).contains(battery.percentage))
        if let health = battery.healthPercent { XCTAssertTrue((30...110).contains(health), "\(health)") }
        if let cycles = battery.cycleCount { XCTAssertGreaterThanOrEqual(cycles, 0) }
    }

    @MainActor
    func testDisplaysWhenAttached() {
        for display in DisplayInfo.current() {
            XCTAssertGreaterThan(display.pixelWidth, 0)
            XCTAssertGreaterThan(display.pixelHeight, 0)
            XCTAssertGreaterThanOrEqual(display.scale, 1)
            XCTAssertFalse(display.name.isEmpty)
        }
    }

    func testNetworkHasNoLoopbackAndMarksOnePrimary() {
        let net = NetworkInfo.current()
        XCTAssertFalse(net.interfaces.contains { $0.name.hasPrefix("lo") })
        XCTAssertLessThanOrEqual(net.interfaces.filter(\.isPrimary).count, 1)
    }

    @MainActor
    func testSnapshotEncodesAndIsFast() throws {
        let started = Date()
        let snapshot = Machine.snapshot()
        let took = Date().timeIntervalSince(started)
        XCTAssertLessThan(took, 1.0, "a snapshot must not launch processes: \(took) s")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        XCTAssertGreaterThan(data.count, 200)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("modelIdentifier"))
    }
}
