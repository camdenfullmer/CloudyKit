// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CloudyKit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CloudyKit",
            targets: ["CloudyKit"]),
    ],
    dependencies: [
        .package(
            name: "Cryptor",
            url: "https://github.com/IBM-Swift/BlueCryptor.git",
            from: "1.0.32"),
        .package(
            name: "CryptorECC",
            url: "https://github.com/IBM-Swift/BlueECC.git",
            from: "1.2.4"),
        .package(
            name: "OpenCombine",
            url: "https://github.com/OpenCombine/OpenCombine.git",
            from: "0.11.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CloudyKit",
            dependencies: [
                "Cryptor",
                "CryptorECC",
                "OpenCombine",
                .product(name: "OpenCombineFoundation", package: "OpenCombine"),
            ]),
        .testTarget(
            name: "CloudyKitTests",
            dependencies: ["CloudyKit"],
            resources: [
                .copy("Assets"),
            ]),
    ]
)
