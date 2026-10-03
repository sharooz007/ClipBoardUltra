// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipBoardUltra",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ClipBoardUltra",
            targets: ["ClipBoardUltra"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClipBoardUltra",
            dependencies: [],
            path: "Sources/ClipBoardUltra"
        )
    ]
)
