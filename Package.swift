// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarbleScroll",
    platforms: [.macOS(.v15)],
    products: [.library(name: "MarbleCore", targets: ["MarbleCore"]),
               .executable(name: "MarbleScroll", targets: ["MarbleScroll"])],
    targets: [.target(name: "MarbleCore"),
              .executableTarget(name: "MarbleScroll", dependencies: ["MarbleCore"]),
              .testTarget(name: "MarbleCoreTests", dependencies: ["MarbleCore"])],
    swiftLanguageModes: [.v5]
)
