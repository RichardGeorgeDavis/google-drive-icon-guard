// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DriveIconGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DriveIconGuardShared",
            targets: ["DriveIconGuardShared"]
        ),
        .library(
            name: "DriveIconGuardScopeInventory",
            targets: ["DriveIconGuardScopeInventory"]
        ),
        .executable(
            name: "drive-icon-guard-scope-inventory",
            targets: ["DriveIconGuardScopeInventoryCLI"]
        )
    ],
    targets: [
        .target(
            name: "DriveIconGuardShared",
            path: "Shared",
            exclude: ["IPC"],
            sources: ["Models", "Utilities"]
        ),
        .target(
            name: "DriveIconGuardScopeInventory",
            dependencies: ["DriveIconGuardShared"],
            path: "App",
            exclude: ["UI", "Logs", "Settings", "XPCClient"],
            sources: ["ScopeInventory"]
        ),
        .executableTarget(
            name: "DriveIconGuardScopeInventoryCLI",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardScopeInventory"
            ],
            path: "Tools/ScopeInventoryCLI"
        ),
        .testTarget(
            name: "DriveIconGuardScopeInventoryTests",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardScopeInventory"
            ],
            path: "Tests/DriveIconGuardScopeInventoryTests"
        )
    ]
)
