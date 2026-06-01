// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Taya",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "TayaCompanion", targets: ["TayaCompanion"]),
    ],
    targets: [
        .target(
            name: "TayaCompanion",
            resources: [.process("Resources")]
        ),
    ]
)
