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
            name: "DriveIconGuardIPC",
            targets: ["DriveIconGuardIPC"]
        ),
        .library(
            name: "DriveIconGuardScopeInventory",
            targets: ["DriveIconGuardScopeInventory"]
        ),
        .library(
            name: "DriveIconGuardXPCClient",
            targets: ["DriveIconGuardXPCClient"]
        ),
        .library(
            name: "DriveIconGuardHelper",
            targets: ["DriveIconGuardHelper"]
        ),
        .library(
            name: "DriveIconGuardRuntimeSupport",
            targets: ["DriveIconGuardRuntimeSupport"]
        ),
        .executable(
            name: "drive-icon-guard-scope-inventory",
            targets: ["DriveIconGuardScopeInventoryCLI"]
        ),
        .executable(
            name: "drive-icon-guard-viewer",
            targets: ["DriveIconGuardViewer"]
        ),
        .executable(
            name: "drive-icon-guard-helper",
            targets: ["DriveIconGuardHelperCLI"]
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
            name: "DriveIconGuardIPC",
            dependencies: ["DriveIconGuardShared"],
            path: "Shared/IPC",
            exclude: ["README.md"]
        ),
        .target(
            name: "DriveIconGuardScopeInventory",
            dependencies: ["DriveIconGuardShared"],
            path: "App",
            exclude: ["UI", "Logs", "Settings", "XPCClient"],
            sources: ["ScopeInventory"]
        ),
        .target(
            name: "DriveIconGuardXPCClient",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardScopeInventory",
                "DriveIconGuardHelper"
            ],
            path: "App/XPCClient",
            exclude: ["README.md"]
        ),
        .target(
            name: "DriveIconGuardHelper",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardScopeInventory"
            ],
            path: "Helper",
            exclude: ["README.md"],
            sources: [
                "ArtefactClassifier",
                "Audit",
                "CircuitBreaker",
                "EventSubscription",
                "PolicyEngine",
                "ProcessClassifier"
            ]
        ),
        .target(
            name: "DriveIconGuardRuntimeSupport",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardHelper"
            ],
            path: "RuntimeHostSupport",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "DriveIconGuardScopeInventoryCLI",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardScopeInventory"
            ],
            path: "Tools/ScopeInventoryCLI"
        ),
        .executableTarget(
            name: "DriveIconGuardViewer",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardScopeInventory",
                "DriveIconGuardIPC",
                "DriveIconGuardXPCClient"
            ],
            path: "App/UI",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "DriveIconGuardHelperCLI",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardScopeInventory",
                "DriveIconGuardHelper",
                "DriveIconGuardXPCClient"
            ],
            path: "Tools/ProtectionHelperCLI"
        ),
        .testTarget(
            name: "DriveIconGuardScopeInventoryTests",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardScopeInventory",
                "DriveIconGuardIPC",
                "DriveIconGuardXPCClient"
            ],
            path: "Tests/DriveIconGuardScopeInventoryTests"
        ),
        .testTarget(
            name: "DriveIconGuardHelperTests",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardScopeInventory",
                "DriveIconGuardHelper"
            ],
            path: "Tests/DriveIconGuardHelperTests"
        ),
        .testTarget(
            name: "DriveIconGuardRuntimeSupportTests",
            dependencies: [
                "DriveIconGuardShared",
                "DriveIconGuardIPC",
                "DriveIconGuardHelper",
                "DriveIconGuardRuntimeSupport"
            ],
            path: "Tests/DriveIconGuardRuntimeSupportTests"
        )
    ]
)
