// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TayaIntelligence",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "TayaIntelligence", targets: ["TayaIntelligence"]),
        .library(name: "TayaCompanion", targets: ["TayaCompanion"]),
        .executable(name: "OrbSandbox", targets: ["OrbSandbox"]),
    ],
    targets: [
        .target(
            name: "TayaIntelligence",
            resources: [.process("Resources")]
        ),
        .target(
            name: "TayaCompanion",
            dependencies: ["TayaIntelligence"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "OrbSandbox",
            dependencies: ["TayaIntelligence"]
        ),
    ]
)
