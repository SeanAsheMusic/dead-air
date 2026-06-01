// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeadAir",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DeadAirCore", targets: ["DeadAirCore"]),
        .executable(name: "DeadAir", targets: ["DeadAirApp"]),
        .executable(name: "DeadAirChecks", targets: ["DeadAirChecks"])
    ],
    targets: [
        .target(name: "DeadAirCore"),
        .executableTarget(
            name: "DeadAirApp",
            dependencies: ["DeadAirCore"]
        ),
        .executableTarget(
            name: "DeadAirChecks",
            dependencies: ["DeadAirCore"],
            path: "Tests/DeadAirCoreChecks"
        )
    ]
)
