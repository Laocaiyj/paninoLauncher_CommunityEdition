// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaninoLauncher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PaninoLauncher", targets: ["PaninoLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "PaninoLauncher",
            path: "PaninoLauncher",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
