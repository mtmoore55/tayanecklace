// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TayaIntelligence",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
            dependencies: ["TayaIntelligence"]
        ),
        .executableTarget(
            name: "OrbSandbox",
            dependencies: ["TayaIntelligence"]
        ),
    ]
)
