// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Um",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Um",
            path: "Um/Sources/Um",
            resources: [
                .copy("../../Resources/Info.plist"),
                .copy("../../Resources/Um.entitlements")
            ]
        )
    ]
)
