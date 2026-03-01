// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DitLog",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "DitLog",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "DitLog",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/CallPrefixes.json"),
            ]
        ),
        .testTarget(
            name: "DitLogTests",
            dependencies: [
                "DitLog",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "DitLogTests"
        ),
    ]
)
