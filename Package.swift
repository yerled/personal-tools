// swift-tools-version:5.9
import PackageDescription

// The core library is Foundation-only so `swift test` can run on Linux.
// AppKit, CoreGraphics, and the menu-bar executable are macOS-only.
var products: [Product] = [
    .library(name: "PersonalToolsCore", targets: ["PersonalToolsCore"])
]
var targets: [Target] = [
    .target(
        name: "PersonalToolsCore",
        path: "Sources/PersonalToolsCore"
    ),
    .testTarget(
        name: "PersonalToolsCoreTests",
        dependencies: ["PersonalToolsCore"],
        path: "Tests/PersonalToolsCoreTests"
    )
]

#if os(macOS)
products.append(.executable(name: "PersonalTools", targets: ["PersonalTools"]))
targets.append(contentsOf: [
    .target(
        name: "PersonalToolsCapture",
        dependencies: ["PersonalToolsCore"],
        path: "Sources/PersonalToolsCapture"
    ),
    .executableTarget(
        name: "PersonalTools",
        dependencies: ["PersonalToolsCore", "PersonalToolsCapture"],
        path: "Sources/PersonalTools"
    ),
    .testTarget(
        name: "PersonalToolsMacTests",
        dependencies: ["PersonalToolsCore", "PersonalToolsCapture"],
        path: "Tests/PersonalToolsMacTests"
    )
])
#endif

let package = Package(
    name: "PersonalTools",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
