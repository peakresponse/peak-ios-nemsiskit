// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NemsisKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NemsisKit",
            targets: ["NemsisKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/peakresponse/Nodal", branch: "xpathnode-access"),
        .package(url: "https://github.com/peakresponse/swift-xml-lint", branch: "dev"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NemsisKit",
            dependencies: [
                .product(name: "Nodal", package: "Nodal"),
                .product(name: "SwiftXMLLint", package: "swift-xml-lint")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "NemsisKitTests",
            dependencies: ["NemsisKit"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
