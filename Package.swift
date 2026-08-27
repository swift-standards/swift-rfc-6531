// swift-tools-version: 6.4

import PackageDescription

extension String {
    static let rfc6531: Self = "RFC 6531"
}

extension Target.Dependency {
    static var asciiSerializerPrimitives: Self {
        .product(name: "ASCII Serializer", package: "swift-ascii-serializer")
    }
    static var asciiParser: Self {
        .product(name: "Parseable ASCII", package: "swift-ascii-parser")
    }
    static var binarySerializable: Self {
        .product(
            name: "Binary Serializable",
            package: "swift-binary-serializer"
        )
    }
    static var incits41986: Self { .product(name: "INCITS 4 1986", package: "swift-incits-4-1986") }
    static var rfc6531: Self { .target(name: .rfc6531) }
    static var rfc1123: Self { .product(name: "RFC 1123", package: "swift-rfc-1123") }
    static var rfc5321: Self { .product(name: "RFC 5321", package: "swift-rfc-5321") }
    static var rfc5322: Self { .product(name: "RFC 5322", package: "swift-rfc-5322") }
}

let package = Package(
    name: "swift-rfc-6531",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
    ],
    products: [
        .library(name: "RFC 6531", targets: ["RFC 6531"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-ascii-serializer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ascii-parser.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-binary-serializer.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-incits/swift-incits-4-1986.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-1123.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-5321.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-5322.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "RFC 6531",
            dependencies: [
                .asciiSerializerPrimitives,
                .asciiParser,
                .binarySerializable,
                .incits41986,
                .rfc1123,
                .rfc5321,
                .rfc5322,
            ]
        ),
        .testTarget(
            name: "RFC 6531 Tests",
            dependencies: [
                "RFC 6531"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension String {
    var tests: Self { self + " Tests" }
    var foundation: Self { self + " Foundation" }
}

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
