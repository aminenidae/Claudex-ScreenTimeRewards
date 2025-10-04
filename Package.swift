// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudexScreenTimeRewards",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "ScreenTimeService", targets: ["ScreenTimeService"]),
        .library(name: "PointsEngine", targets: ["PointsEngine"]),
        .library(name: "SyncKit", targets: ["SyncKit"])
    ],
    targets: [
        .target(name: "Core", path: "Sources/Core"),
        .target(name: "ScreenTimeService", dependencies: ["Core"], path: "Sources/ScreenTimeService"),
        .target(name: "PointsEngine", dependencies: ["Core"], path: "Sources/PointsEngine"),
        .target(name: "SyncKit", dependencies: ["Core"], path: "Sources/SyncKit"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests")
    ]
)

