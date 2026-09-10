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
        ),
        .executable(
            name: "localdocs-example",
            targets: ["LocalDocsExample"]
        )
    ],
    targets: [
        .target(
            name: "LocalDocsCore",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "LocalDocsExample",
            dependencies: ["LocalDocsCore"]
        ),
        .testTarget(
            name: "LocalDocsCoreTests",
            dependencies: ["LocalDocsCore"]
        )
    ]
)
