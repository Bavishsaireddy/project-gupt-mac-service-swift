// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteDesktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RemoteDesktop", targets: ["RemoteDesktop"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "RemoteDesktop",
            path: "RemoteDesktop/RemoteDesktop",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Network"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
