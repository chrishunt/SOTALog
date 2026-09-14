// swift-tools-version: 5.9
import PackageDescription

// HamCore is the amateur-radio domain layer shared by SOTA Log and other apps:
// the models, the GRDB logbook and reference database, ADIF, the band plan,
// callsign utilities, and the SOTA, POTA and QRZ clients. No UI, no radio code.
let package = Package(
    name: "HamCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HamCore", targets: ["HamCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "HamCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "HamCoreTests",
            dependencies: [
                "HamCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
