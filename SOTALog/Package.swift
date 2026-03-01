// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SOTALog",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "SOTALog",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "SOTALog",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/CallPrefixes.json"),
            ]
        ),
        .testTarget(
            name: "SOTALogTests",
            dependencies: [
                "SOTALog",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "SOTALogTests"
        ),
    ]
)
