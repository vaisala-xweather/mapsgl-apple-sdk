// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.7.1"
let xcframeworkChecksums = (
    core: "09fa7d13db96008229ddabceaa455641f009b46420a38c99108ac05fc6cde531",
    renderer: "dfc784ff01e300e3a43a9047fe1361e25f3009a083e3d5a41e8ff4712c9395c4",
    maps: "041f61f4f3b31e21864b123b3c90666a4d570f03eb93d5f72932f86175519846"
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
