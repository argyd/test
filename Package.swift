// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EjectBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EjectBar", targets: ["EjectBar"])
    ],
    targets: [
        .executableTarget(name: "EjectBar"),
        .testTarget(name: "EjectBarTests", dependencies: ["EjectBar"])
    ]
)
