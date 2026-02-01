// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSpeedMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NetBar",
            targets: ["NetSpeedMonitor"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "NetTrafficStat",
            path: "Sources/NetTrafficStat"
        ),
        .executableTarget(
            name: "NetSpeedMonitor",
            dependencies: [
                "NetTrafficStat",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin")
            ],
            path: "Sources/NetSpeedMonitor",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
