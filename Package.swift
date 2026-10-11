// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-machine-info",
    // Mac-only by nature: the interesting parts (IOKit power sources, the
    // device tree's product name, NSScreen) exist nowhere else.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MachineInfo", targets: ["MachineInfo"]),
    ],
    targets: [
        .target(name: "MachineInfo"),
        .testTarget(name: "MachineInfoTests", dependencies: ["MachineInfo"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
