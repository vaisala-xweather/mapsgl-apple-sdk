// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.8.0"
let xcframeworkChecksums = (
    core: "d1cc7976ad12a8d2a5073705000b0a1103532e9367c96b76406ffb6b96f324c4",
    renderer: "2824da89124201dfcb59f1664d0238f4797feca9a99a986f61f66eceb5f381e1",
    maps: "037fac97867f4b33b43f4e85a9aa80e13c6c65a9f619bb2bfd2cec528bb736fd"
)

let package = Package(
    name: "MapsGL",
    platforms: [ .iOS(.v16), .macCatalyst(.v16), .visionOS(.v1) ],
    products: [
        .library(name: "MapsGL", targets: [
            "MapsGLRendererWrapper",
            "MapsGLMapsWrapper",
            "MapsGLMapbox",
        ]),
    ],
    dependencies: [
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", "11.0.0-0"..<"12.0.0"),
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

        .target(name: "MapsGLMapbox",
            dependencies: [
                "MapsGLMaps",
                .product(name: "MapboxMaps", package: "mapbox-maps-ios"),
            ],
            path: "Sources/MapsGLMapbox"
        ),
    ]
)
