// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "VirtualDisplayBridge",
            path: "Sources/VirtualDisplayBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "HyperMac",
            dependencies: ["VirtualDisplayBridge"],
            path: "Sources",
            exclude: ["VirtualDisplayBridge"],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
