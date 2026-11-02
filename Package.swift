// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EdgeBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EdgeBar", targets: ["EdgeBar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EdgeBar",
            dependencies: [],
            path: "Sources/EdgeBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "EdgeBarTests",
            dependencies: ["EdgeBar"],
            path: "Tests/EdgeBarTests"
        )
    ]
)
