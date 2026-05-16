// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FoldermixDesktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FoldermixDesktop", targets: ["FoldermixDesktop"])
    ],
    targets: [
        .executableTarget(
            name: "FoldermixDesktop",
            path: "Sources/FoldermixDesktop"
        )
    ]
)
