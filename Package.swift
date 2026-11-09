// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotchDino",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "NotchDino", targets: ["NotchDino"])],
    dependencies: [
        .package(url: "https://github.com/neelrocketbots/notchkit.git", from: "0.1.0"),
    ],
    targets: [
        .target(name: "RunnerCore"),
        .target(name: "RaceCore", dependencies: ["RunnerCore"]),
        .target(name: "NotchDinoApp",
                dependencies: ["RunnerCore", "RaceCore", .product(name: "NotchKit", package: "notchkit")]),
        .executableTarget(name: "NotchDino", dependencies: ["NotchDinoApp"]),
        .testTarget(name: "RunnerCoreTests", dependencies: ["RunnerCore"]),
        .testTarget(name: "RaceCoreTests", dependencies: ["RaceCore", "RunnerCore"]),
        .testTarget(name: "NotchDinoTests", dependencies: ["NotchDinoApp", "RunnerCore", "RaceCore"]),
    ]
)
