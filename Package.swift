// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rezfish",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "rezfish",
            path: "Sources/rezfish",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
