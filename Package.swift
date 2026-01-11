// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rfc-8058",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(
            name: "RFC 8058",
            targets: ["RFC 8058"]
        )
    ],
    dependencies: [
        .package(path: "../swift-rfc-3987")
    ],
    targets: [
        .target(
            name: "RFC 8058",
            dependencies: [
                .product(name: "RFC 3987", package: "swift-rfc-3987")
            ]
        ),
        .testTarget(
            name: "RFC 8058".tests,
            dependencies: [
                "RFC 8058",
                .product(name: "RFC 3987 Foundation", package: "swift-rfc-3987")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension String {
    var tests: Self { self + " Tests" }
    var foundation: Self { self + " Foundation" }
}

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings =
        existing + [
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
        ]
}
