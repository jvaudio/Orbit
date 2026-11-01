// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "OrbitCore", targets: ["OrbitCore"]), .executable(name: "Orbit", targets: ["Orbit"])],
    targets: [
        .target(name: "OrbitCore"),
        .executableTarget(name: "Orbit", dependencies: ["OrbitCore"]),
        .testTarget(name: "OrbitCoreTests", dependencies: ["OrbitCore"]),
        .testTarget(name: "OrbitTests", dependencies: ["Orbit", "OrbitCore"])
    ]
)
