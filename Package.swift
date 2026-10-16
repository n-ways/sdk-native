// swift-tools-version:5.9
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 N-WAYS LIMITED
import PackageDescription

let package = Package(
    name: "NWaysMaps",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "NWaysMaps", targets: ["NWaysMaps"]),
    ],
    dependencies: [
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", exact: "6.31.0"),
    ],
    targets: [
        .target(
            name: "NWaysMaps",
            dependencies: [
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
            ]
        ),
        .testTarget(
            name: "NWaysMapsTests",
            dependencies: ["NWaysMaps"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
