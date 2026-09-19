// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DotDropEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DotDropEngine", targets: ["DotDropEngine"])
    ],
    targets: [
        .target(name: "DotDropEngine"),
        .testTarget(
            name: "DotDropEngineTests",
            dependencies: ["DotDropEngine"],
            path: "Tests",
            sources: ["DotDropEngineTests"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
