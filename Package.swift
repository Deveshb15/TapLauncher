// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TapLauncher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TapLauncher",
            resources: [.copy("Resources/audio")],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
