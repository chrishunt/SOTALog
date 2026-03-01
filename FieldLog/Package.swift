// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FieldLog",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "FieldLog",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "FieldLog",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/CallPrefixes.json"),
            ]
        ),
        .testTarget(
            name: "FieldLogTests",
            dependencies: [
                "FieldLog",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "FieldLogTests"
        ),
    ]
)
