// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.6.0-beta.1"
let xcframeworkChecksums = (
    core: "3e8b9a3616c59686f1a45f752de9bdcb2d9e6ae77b46dcf1afb9b54c841d4571",
    renderer: "ea414e692f8a5ece1b8ca561ea9241314a30eefdb99b27016062cfd3fc288d89",
    maps: "cc13ea4c9b9370b581c82883c7770cfb87a0cccf48435e6e6af128f474463aa4"
)

let package = Package(
    name: "MapsGL",
    platforms: [ .iOS(.v16), .macCatalyst(.v16), .visionOS(.v1) ],
    products: [
        .library(name: "MapsGL", targets: [
            "MapsGLRendererWrapper",
            "MapsGLMapsWrapper",
            "MapsGLMapLibre",
        ]),
    ],
    dependencies: [
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.18.0"),
        .package(url: "https://github.com/mapbox/turf-swift.git", exact: "4.0.0"),
    ],
    targets: [
        .binaryTarget(name: "MapsGLCore",
            url: "https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/\(version)/MapsGLCore.xcframework.zip",
            checksum: xcframeworkChecksums.core
        ),

        .target(name: "MapsGLRendererWrapper",
            dependencies: [
                "MapsGLCore",
                "MapsGLRenderer",
            ]
        ),
        .binaryTarget(name: "MapsGLRenderer",
            url: "https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/\(version)/MapsGLRenderer.xcframework.zip",
            checksum: xcframeworkChecksums.renderer
        ),

        .target(name: "MapsGLMapsWrapper",
            dependencies: [
                "MapsGLCore",
                "MapsGLRenderer",
                "MapsGLMaps",
                .product(name: "Turf", package: "turf-swift"),
            ]
        ),
        .binaryTarget(name: "MapsGLMaps",
            url: "https://cdn.aerisapi.com/sdk/ios/mapsgl/releases/\(version)/MapsGLMaps.xcframework.zip",
            checksum: xcframeworkChecksums.maps
        ),

        .target(name: "MapsGLMapLibre",
            dependencies: [
                "MapsGLMaps",
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
            ],
            path: "Sources/MapsGLMapLibre",
            swiftSettings: [
                .define("MLN_RENDER_BACKEND_METAL"),
            ]
        ),
    ]
)
