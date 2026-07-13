// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CommandBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "CommandBar",
            targets: ["CommandBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CommandBar",
            path: "CommandBar",
            exclude: [
                ".DS_Store"
            ],
            sources: [
                "CommandBar.swift",
                "Modules/LaunchAgentHealthModule.swift",
                "Modules/TemporalModule.swift",
                "Modules/WiFiModule.swift",
                "Modules/VMManagerModule.swift",
                "Modules/DockerManagerModule.swift"
            ],
            swiftSettings: [
                .define("COMMANDBAR_APP")
            ]
        )
    ]
)
