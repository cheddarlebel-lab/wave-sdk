// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WaveUnlock",
    platforms: [.iOS(.v15), .watchOS(.v8), .macOS(.v12)],
    products: [
        .library(name: "WaveUnlock", targets: ["WaveUnlock"]),
        .library(name: "WaveUnlockUI", targets: ["WaveUnlockUI"]),
    ],
    targets: [
        .target(name: "WaveUnlock"),
        .target(name: "WaveUnlockUI", dependencies: ["WaveUnlock"]),
        .testTarget(
            name: "WaveUnlockTests",
            dependencies: ["WaveUnlock"],
            resources: [.copy("Vectors")]
        ),
    ]
)
