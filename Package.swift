// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Um",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "Um",
            dependencies: ["SwiftWhisper"],
            path: "Um/Sources/Um",
            resources: [
                .copy("../../Resources/Info.plist"),
                .copy("../../Resources/Um.entitlements")
            ]
        )
    ]
)
