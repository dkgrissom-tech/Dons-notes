// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "DonsNotes",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DonsNotes",
            targets: ["DonsNotes"]),
    ],
    targets: [
        .target(
            name: "DonsNotes",
            path: "Sources",
            resources: [
                .process("../Resources/Assets.xcassets")
            ])
    ]
)
