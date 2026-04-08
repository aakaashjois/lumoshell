// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lumoshell-appearance-sync-agent",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "lumoshell-appearance-sync-agent",
            targets: ["lumoshell-appearance-sync-agent"]
        )
    ],
    targets: [
        .executableTarget(
            name: "lumoshell-appearance-sync-agent",
            dependencies: []
        ),
        .testTarget(
            name: "lumoshell-appearance-sync-agentTests",
            dependencies: ["lumoshell-appearance-sync-agent"]
        )
    ]
)
