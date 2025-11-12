// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-rfc-8058",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "RFC 8058",
            targets: ["RFC 8058"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-rfc-3987.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "RFC 8058",
            dependencies: [
                .product(name: "RFC 3987", package: "swift-rfc-3987")
            ]
        ),
        .testTarget(
            name: "RFC 8058 Tests",
            dependencies: ["RFC 8058"]
        )
    ]
)

for target in package.targets {
    target.swiftSettings?.append(
        contentsOf: [
            .enableUpcomingFeature("MemberImportVisibility")
        ]
    )
}
