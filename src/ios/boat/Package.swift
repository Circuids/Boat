// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "boat",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "boat", targets: ["boat"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "boat",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // Privacy manifest declaring microphone usage and required-reason APIs.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
