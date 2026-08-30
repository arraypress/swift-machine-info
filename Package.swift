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
