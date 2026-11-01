// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "OrbitCore", targets: ["OrbitCore"]), .executable(name: "Orbit", targets: ["Orbit"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .target(name: "OrbitCore"),
        .executableTarget(name: "Orbit", dependencies: ["OrbitCore", .product(name: "Sparkle", package: "Sparkle")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "OrbitCoreTests", dependencies: ["OrbitCore"]),
        .testTarget(name: "OrbitTests", dependencies: ["Orbit", "OrbitCore"])
    ]
)
