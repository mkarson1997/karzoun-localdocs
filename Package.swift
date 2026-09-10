// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KarzounLocalDocs",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "LocalDocsCore",
            targets: ["LocalDocsCore"]
        )
    ],
    targets: [
        .target(
            name: "LocalDocsCore"
        ),
        .testTarget(
            name: "LocalDocsCoreTests",
            dependencies: ["LocalDocsCore"]
        )
    ]
)
