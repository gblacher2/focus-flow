// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FocusFlow", targets: ["FocusFlow"]),
        .library(name: "FocusFlowCore", targets: ["FocusFlowCore"])
    ],
    targets: [
        .target(
            name: "FocusFlowCore",
            path: "Sources/FocusFlowCore"
        ),
        .executableTarget(
            name: "FocusFlow",
            dependencies: ["FocusFlowCore"],
            path: "Sources/FocusFlow"
        ),
        .executableTarget(
            name: "SelfTests",
            dependencies: ["FocusFlowCore"],
            path: "Sources/SelfTests"
        ),
        .testTarget(
            name: "FocusFlowTests",
            dependencies: ["FocusFlowCore"],
            path: "Tests/FocusFlowTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
