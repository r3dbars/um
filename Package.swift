// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Um",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "UmCore", targets: ["UmCore"]),
        .executable(name: "Um", targets: ["Um"])
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", revision: "c340197966ebd264f3135d3955874b40f8ed58bc")
    ],
    targets: [
        .target(
            name: "UmCore",
            path: "Um/Sources/UmCore"
        ),
        .executableTarget(
            name: "Um",
            dependencies: [
                "UmCore",
                .product(name: "SwiftWhisper", package: "SwiftWhisper")
            ],
            path: "Um/Sources/Um"
        ),
        .testTarget(
            name: "UmCoreTests",
            dependencies: ["UmCore"],
            path: "Tests/UmCoreTests"
        )
    ]
)
