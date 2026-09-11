// swift-tools-version: 6.0

import PackageDescription

internal let package = Package(
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
            name: "LocalDocsCore",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "LocalDocsCoreTests",
            dependencies: ["LocalDocsCore"]
        )
    ]
)
