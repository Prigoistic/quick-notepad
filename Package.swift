// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickNotepad",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "QuickNotepadCore"
        ),
        .executableTarget(
            name: "QuickNotepad",
            dependencies: ["QuickNotepadCore"]
        ),
        .testTarget(
            name: "QuickNotepadCoreTests",
            dependencies: ["QuickNotepadCore"]
        ),
    ]
)
