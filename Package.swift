// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PDFOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PDFOS",
            targets: ["PDFOS"]
        ),
        .library(
            name: "PDFOSCore",
            targets: ["PDFOSCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "PDFOS",
            dependencies: ["PDFOSCore"],
            path: "PDFOS",
            sources: ["main.swift"]
        ),

        // Core library target
        .target(
            name: "PDFOSCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "PDFOS",
            exclude: [
                "Tests",
                "main.swift",
                "Core/Storage/PerformanceOptimizer.swift",
                "UI/Views/EnhancedTimelineView.swift",
                "UI/Onboarding/OnboardingView.swift"
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Test targets
        .testTarget(
            name: "SemanticTests",
            dependencies: ["PDFOSCore"],
            path: "PDFOS/Tests/SemanticTests"
        ),
        .testTarget(
            name: "PerformanceTests",
            dependencies: ["PDFOSCore"],
            path: "PDFOS/Tests/PerformanceTests"
        )
    ]
)
