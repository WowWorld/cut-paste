// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CutPaste",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CutPaste", targets: ["CutPaste"])
    ],
    targets: [
        .executableTarget(
            name: "CutPaste",
            path: "Sources/CutPaste",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
