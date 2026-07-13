// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuotaCapsule",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuotaCapsuleCore", targets: ["QuotaCapsuleCore"]),
        .executable(name: "QuotaCapsuleMac", targets: ["QuotaCapsuleMac"])
    ],
    targets: [
        .target(name: "QuotaCapsuleCore"),
        .executableTarget(
            name: "QuotaCapsuleMac",
            dependencies: ["QuotaCapsuleCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "QuotaCapsuleCoreSpec",
            dependencies: ["QuotaCapsuleCore"]
        ),
        .testTarget(
            name: "QuotaCapsuleCoreTests",
            dependencies: ["QuotaCapsuleCore"]
        )
    ]
)
