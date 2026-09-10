//
//  RunningStateTests.swift
//  MachineInfo
//
//  Created by David Sherlock on 2026.
//
//  The live half — apps, windows, storage, audio, staying awake — run on
//  a real Mac with no permissions granted: a machine with no running apps
//  or no root volume is a read gone wrong, not a strange machine. The
//  rules that need no machine are pinned on hand-made values.
//

import AppKit
import CoreAudio
import Foundation
import XCTest
@testable import MachineInfo

final class RunningAppsTests: XCTestCase {

    @MainActor
    func testTheWorkspaceListsAtLeastOneOrdinaryApp() {
        let apps = RunningApps.current()
        XCTAssertFalse(apps.isEmpty)
        XCTAssertTrue(apps.contains { $0.activationPolicy == .regular }, "no Dock app running?")
        XCTAssertTrue(apps.allSatisfy { $0.pid > 0 })
        XCTAssertTrue(apps.allSatisfy { !$0.name.isEmpty })
    }

    @MainActor
    func testDockAppsComeFirstThenAgentsThenBackground() {
        let ranks = RunningApps.current().map { app -> Int in
            switch app.activationPolicy {
            case .regular: 0
            case .accessory: 1
            case .prohibited: 2
            }
        }
        XCTAssertEqual(ranks, ranks.sorted())
    }

    @MainActor
    func testTheFrontmostAppIsInTheList() {
        guard let front = RunningApps.frontmost() else { return }  // headless session
        XCTAssertTrue(RunningApps.current().contains { $0.pid == front.pid })
        XCTAssertTrue(front.isActive)
    }

    @MainActor
    func testQuittingSomethingThatIsNotRunningIsRefusedByName() {
        XCTAssertThrowsError(try RunningApps.quit("com.example.not-a-real-app-90210")) { error in
            XCTAssertEqual(error as? MachineInfoError, .notRunning("com.example.not-a-real-app-90210"))
            XCTAssertTrue(error.localizedDescription.contains("not running"))
        }
    }

    @MainActor
    func testFinderIsProtectedWhenItIsRunning() {
        let finder = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }
        guard finder != nil else { return }  // a session without Finder
        XCTAssertThrowsError(try RunningApps.quit("com.apple.finder")) { error in
            XCTAssertEqual(error as? MachineInfoError, .protectedProcess("Finder"))
        }
        XCTAssertThrowsError(try RunningApps.quit("finder", force: true))
    }

    func testThePolicyMapping() {
        XCTAssertEqual(AppReading.policy(.regular), .regular)
        XCTAssertEqual(AppReading.policy(.accessory), .accessory)
        XCTAssertEqual(AppReading.policy(.prohibited), .prohibited)
        XCTAssertEqual(ActivationPolicy.allCases.count, 3)
    }

    func testTheOrderingRule() {
        let dock = RunningApp(name: "Safari", bundleIdentifier: "com.apple.Safari", pid: 1, isActive: false,
                              isHidden: false, launchedAt: nil, activationPolicy: .regular)
        let agent = RunningApp(name: "Alfred", bundleIdentifier: "com.runningwithcrayons.Alfred", pid: 2,
                               isActive: false, isHidden: false, launchedAt: nil, activationPolicy: .accessory)
        let daemon = RunningApp(name: "a-daemon", bundleIdentifier: nil, pid: 3, isActive: false,
                                isHidden: false, launchedAt: nil, activationPolicy: .prohibited)
        let mail = RunningApp(name: "mail", bundleIdentifier: "com.apple.mail", pid: 4, isActive: false,
                              isHidden: false, launchedAt: nil, activationPolicy: .regular)
        let sorted = [daemon, agent, dock, mail].sorted(by: AppReading.order)
        XCTAssertEqual(sorted.map(\.name), ["mail", "Safari", "Alfred", "a-daemon"], "case-insensitive within a group")
    }

    @MainActor
    func testMatchingPrefersBundleThenNameThenPrefix() {
        let apps = NSWorkspace.shared.runningApplications
        guard let any = apps.first(where: { $0.localizedName != nil && $0.bundleIdentifier != nil }) else { return }
        let byBundle = AppReading.match(any.bundleIdentifier!.uppercased(), in: apps)
        XCTAssertEqual(byBundle?.processIdentifier, any.processIdentifier, "bundle identifiers match case-insensitively")
        XCTAssertNotNil(AppReading.match(any.localizedName!, in: apps))
        XCTAssertNotNil(AppReading.match(String(any.localizedName!.prefix(3)), in: apps), "a prefix is enough")
        XCTAssertNil(AppReading.match("   ", in: apps))
        XCTAssertNil(AppReading.match("zzz-no-such-app", in: apps))
    }

    func testTheProtectedList() {
        XCTAssertTrue(ProtectedProcesses.isProtected(bundleIdentifier: "com.apple.finder", pid: 99, ownPID: 1))
        XCTAssertTrue(ProtectedProcesses.isProtected(bundleIdentifier: "COM.APPLE.LOGINWINDOW", pid: 99, ownPID: 1))
        XCTAssertTrue(ProtectedProcesses.isProtected(bundleIdentifier: nil, pid: 1, ownPID: 1), "never itself")
        XCTAssertFalse(ProtectedProcesses.isProtected(bundleIdentifier: "com.apple.Safari", pid: 99, ownPID: 1))
        XCTAssertFalse(ProtectedProcesses.isProtected(bundleIdentifier: nil, pid: 99, ownPID: 1))
    }
}

final class WindowsTests: XCTestCase {

    func testTheWindowListReturns() {
        let windows = Windows.list()
        XCTAssertTrue(windows.allSatisfy { $0.ownerPID > 0 && !$0.ownerName.isEmpty })
        XCTAssertTrue(windows.allSatisfy { $0.bounds.width >= 0 && $0.bounds.height >= 0 })
        let everything = Windows.list(onScreenOnly: false)
        XCTAssertGreaterThanOrEqual(everything.count, windows.count)
    }

    @MainActor
    func testTheFrontWindowIsAnOrdinaryOneWhenThereIsOne() {
        guard let front = Windows.front() else { return }  // nothing on screen
        XCTAssertEqual(front.layer, 0)
        XCTAssertTrue(front.isOnScreen)
    }

    func testTitlesAreNilNotEmptyWhenWithheld() {
        // Without Screen Recording every other app's title is withheld; the
        // model must say nil, never "". This process has no windows of its
        // own, so on an unpermitted machine every title here is nil.
        let titles = Windows.list().map(\.title)
        XCTAssertFalse(titles.contains(""))
        let withheld = titles.filter { $0 == nil }.count
        let titled = Windows.list().filter { $0.title != nil }.map { "\($0.ownerName)(\($0.ownerPID))=\($0.title!)" }
        print("PROBE screen-recording: \(titles.count) windows, \(withheld) without a title; titled: \(titled) own pid \(ProcessInfo.processInfo.processIdentifier)")
    }

    func testReadingAWindowDictionary() throws {
        let entry: [String: Any] = [
            "kCGWindowOwnerName": "Safari", "kCGWindowOwnerPID": 501, "kCGWindowNumber": 42,
            "kCGWindowName": "Apple", "kCGWindowLayer": 0, "kCGWindowIsOnscreen": 1,
            "kCGWindowBounds": ["X": 10, "Y": 20.5, "Width": 800, "Height": 600],
        ]
        let window = try XCTUnwrap(WindowListing.window(entry))
        XCTAssertEqual(window.ownerName, "Safari")
        XCTAssertEqual(window.ownerPID, 501)
        XCTAssertEqual(window.windowNumber, 42)
        XCTAssertEqual(window.title, "Apple")
        XCTAssertEqual(window.bounds, WindowBounds(x: 10, y: 20.5, width: 800, height: 600))
        XCTAssertEqual(window.layer, 0)
        XCTAssertTrue(window.isOnScreen)
    }

    func testAWithheldOrEmptyTitleIsNil() throws {
        var entry: [String: Any] = [
            "kCGWindowOwnerName": "Mail", "kCGWindowOwnerPID": Int32(7), "kCGWindowNumber": 1,
            "kCGWindowBounds": ["X": 0, "Y": 0, "Width": 1, "Height": 1],
        ]
        XCTAssertNil(try XCTUnwrap(WindowListing.window(entry)).title)
        entry["kCGWindowName"] = ""
        XCTAssertNil(try XCTUnwrap(WindowListing.window(entry)).title)
        XCTAssertEqual(try XCTUnwrap(WindowListing.window(entry)).layer, 0, "no layer means an ordinary window")
        XCTAssertFalse(try XCTUnwrap(WindowListing.window(entry)).isOnScreen, "no flag means off screen")
    }

    func testADictionaryMissingWhatEveryWindowHasIsSkipped() {
        XCTAssertNil(WindowListing.window(["kCGWindowOwnerName": "X"]))
        XCTAssertNil(WindowListing.window(["kCGWindowOwnerName": "X", "kCGWindowOwnerPID": 1, "kCGWindowNumber": 2]))
        XCTAssertNil(WindowListing.window(["kCGWindowOwnerName": "X", "kCGWindowOwnerPID": 1, "kCGWindowNumber": 2,
                                           "kCGWindowBounds": ["X": 0, "Y": 0]]))
        XCTAssertNil(WindowListing.bounds(["X": 1, "Y": 2, "Width": 3]))
    }

    func testTheFrontRule() {
        func window(_ pid: Int32, layer: Int) -> WindowInfo {
            WindowInfo(ownerName: "app", ownerPID: pid, windowNumber: Int(pid) * 10 + layer, title: nil,
                       bounds: WindowBounds(x: 0, y: 0, width: 1, height: 1), layer: layer, isOnScreen: true)
        }
        let windows = [window(1, layer: 25), window(2, layer: 0), window(3, layer: 0)]
        XCTAssertEqual(WindowListing.front(of: windows, activePID: 3)?.ownerPID, 3, "the active app's window wins")
        XCTAssertEqual(WindowListing.front(of: windows, activePID: 9)?.ownerPID, 2, "else the first ordinary window")
        XCTAssertEqual(WindowListing.front(of: windows, activePID: nil)?.ownerPID, 2)
        XCTAssertNil(WindowListing.front(of: [window(1, layer: 25)], activePID: 1), "a menu is not a document window")
    }
}

final class StorageTests: XCTestCase {

    func testTheRootVolumeHasRoom() throws {
        let root = try Storage.free(at: "/")
        XCTAssertEqual(root.path, "/")
        XCTAssertGreaterThan(root.totalBytes, 50 << 30)
        XCTAssertGreaterThan(root.freeBytes, 0)
        XCTAssertLessThanOrEqual(root.freeBytes, root.totalBytes)
        XCTAssertEqual(root.usedBytes, root.totalBytes - root.freeBytes)
        if let important = root.availableForImportantUsageBytes {
            XCTAssertGreaterThanOrEqual(important, root.freeBytes, "purgeable space only adds")
        }
    }

    func testAPathOffAnyVolumeIsRefused() {
        XCTAssertThrowsError(try Storage.free(at: "/no/such/place/at/all")) { error in
            XCTAssertEqual(error as? MachineInfoError, .storageUnreadable("/no/such/place/at/all"))
            XCTAssertTrue(error.localizedDescription.contains("no volume"))
        }
    }

    func testTheArithmetic() {
        let info = StorageMath.info(path: "/x", total: 1000, free: 250, important: 300)
        XCTAssertEqual(info.usedBytes, 750)
        XCTAssertEqual(StorageMath.info(path: "/x", total: 100, free: 150, important: nil).usedBytes, 0, "never negative")
        XCTAssertEqual(StorageMath.percentUsed(total: 1000, free: 250), 75)
        XCTAssertEqual(StorageMath.percentUsed(total: 0, free: 0), 0)
        XCTAssertEqual(StorageMath.percentUsed(total: 3, free: 1), 67)
        XCTAssertEqual(StorageMath.bytesText(0), "Zero KB")
        XCTAssertTrue(StorageMath.bytesText(1_000_000_000).contains("GB"))
    }
}

final class AudioDevicesTests: XCTestCase {

    func testAMacHasAudioDevices() {
        let devices = AudioDevices.all()
        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.allSatisfy { !$0.name.isEmpty && $0.transportCode.count == 4 || $0.transportCode.hasPrefix("0x") })
        XCTAssertLessThanOrEqual(devices.filter(\.isDefaultOutput).count, 1)
        XCTAssertLessThanOrEqual(devices.filter(\.isDefaultInput).count, 1)
        if let output = AudioDevices.output() {
            XCTAssertTrue(output.isOutput)
            XCTAssertTrue(devices.contains(output))
        }
    }

    func testTheTransportCodes() {
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeBuiltIn), .builtIn)
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeUSB), .usb)
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeBluetooth), .bluetooth)
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeHDMI), .hdmi)
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeAirPlay), .airPlay)
        XCTAssertEqual(AudioTransports.transport(forCode: kAudioDeviceTransportTypeAggregate), .aggregate)
        XCTAssertEqual(AudioTransports.transport(forCode: 0x12345678), .other)
        XCTAssertEqual(AudioTransports.text(forCode: kAudioDeviceTransportTypeBuiltIn), "bltn")
        XCTAssertEqual(AudioTransports.text(forCode: kAudioDeviceTransportTypeUSB), "usb ")
        XCTAssertEqual(AudioTransports.text(forCode: 0), "0x00000000")
        XCTAssertEqual(AudioTransport.allCases.count, 15)
    }

    func testMatchingByName() {
        func device(_ id: UInt32, _ name: String) -> AudioDevice {
            AudioDevice(id: id, name: name, uid: nil, transport: .usb, transportCode: "usb ", isInput: false,
                        isOutput: true, isDefaultOutput: false, isDefaultInput: false, sampleRate: nil)
        }
        let devices = [device(1, "MacBook Pro Speakers"), device(2, "AirPods Pro"), device(3, "Pro Display XDR")]
        XCTAssertEqual(AudioMatching.match("airpods pro", in: devices)?.id, 2, "exact, case-insensitive")
        XCTAssertEqual(AudioMatching.match("AirPods", in: devices)?.id, 2, "a prefix")
        XCTAssertEqual(AudioMatching.match("XDR", in: devices)?.id, 3, "a substring")
        XCTAssertEqual(AudioMatching.match("Pro", in: devices)?.id, 3, "one name starts with it, so the prefix step decides before the substring tie")
        XCTAssertNil(AudioMatching.match("o", in: devices), "ambiguous at every step")
        XCTAssertNil(AudioMatching.match("Speakers", in: [device(1, "Speakers"), device(2, "speakers")]), "two exact matches is still no answer")
        XCTAssertNil(AudioMatching.match("", in: devices))
        XCTAssertNil(AudioMatching.match("Nope", in: devices))
    }

    func testSettingAnUnknownOutputIsRefused() {
        XCTAssertThrowsError(try AudioDevices.setOutput(id: 0)) { error in
            XCTAssertEqual(error as? MachineInfoError, .audioDeviceNotFound("device 0"))
        }
        XCTAssertThrowsError(try AudioDevices.setOutput(named: "no such device 90210"))
    }
}

final class KeepAwakeTests: XCTestCase {

    func testATokenHoldsAndReleases() throws {
        let token = try KeepAwake.begin(reason: "MachineInfo test")
        XCTAssertTrue(token.isActive)
        XCTAssertEqual(token.reason, "MachineInfo test")
        XCTAssertFalse(token.preventsDisplaySleep)
        token.end()
        XCTAssertFalse(token.isActive)
        token.end()  // twice is fine
        XCTAssertFalse(token.isActive)
    }

    func testTheDisplayVariant() throws {
        let token = try KeepAwake.begin(reason: "MachineInfo display test", preventDisplaySleep: true)
        XCTAssertTrue(token.preventsDisplaySleep)
        token.end()
    }

    func testTheScopedFormReturnsTheBodysValueAndReleases() throws {
        let value = try KeepAwake.while(reason: "MachineInfo scoped test") { 42 }
        XCTAssertEqual(value, 42)
        struct Boom: Error {}
        XCTAssertThrowsError(try KeepAwake.while(reason: "MachineInfo throwing test") { throw Boom() })
    }
}

final class RunningStateCodableTests: XCTestCase {

    func testEveryNewModelRoundTrips() throws {
        let app = RunningApp(name: "Safari", bundleIdentifier: "com.apple.Safari", pid: 12, isActive: true,
                             isHidden: false, launchedAt: Date(timeIntervalSince1970: 1_700_000_000), activationPolicy: .regular)
        let window = WindowInfo(ownerName: "Safari", ownerPID: 12, windowNumber: 3, title: nil,
                                bounds: WindowBounds(x: 1, y: 2, width: 3, height: 4), layer: 0, isOnScreen: true)
        let storage = StorageMath.info(path: "/", total: 10, free: 4, important: 5)
        let device = AudioDevice(id: 5, name: "Speakers", uid: "BuiltInSpeakerDevice", transport: .builtIn,
                                 transportCode: "bltn", isInput: false, isOutput: true, isDefaultOutput: true,
                                 isDefaultInput: false, sampleRate: 48_000)
        func roundTrip<T: Codable>(_ value: T) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
        }
        XCTAssertEqual(try roundTrip(app).bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(try roundTrip(app).activationPolicy, .regular)
        XCTAssertEqual(try roundTrip(window).bounds, window.bounds)
        XCTAssertNil(try roundTrip(window).title)
        XCTAssertEqual(try roundTrip(storage), storage)
        XCTAssertEqual(try roundTrip(device), device)
        for policy in ActivationPolicy.allCases { XCTAssertEqual(try roundTrip(policy), policy) }
        for transport in AudioTransport.allCases { XCTAssertEqual(try roundTrip(transport), transport) }
    }

    func testEveryErrorHasWords() {
        let errors: [MachineInfoError] = [
            .notRunning("x"), .protectedProcess("Finder"), .assertionFailed(-1), .audioDeviceNotFound("y"),
            .audioError(-50), .storageUnreadable("/z"),
        ]
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.localizedDescription.contains("MachineInfoError"), "no type names in messages")
        }
    }
}
