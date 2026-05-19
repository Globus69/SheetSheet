// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SheetSheet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SheetSheet",
            path: "Sources/SheetSheet",
            resources: [
                .process("Resources/SheetSheet.entitlements")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
