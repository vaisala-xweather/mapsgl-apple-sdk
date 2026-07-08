// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.6.1"
let xcframeworkChecksums = (
    core: "b11f2691a0d99a2926134cbf366d942815c43b805ce34ccd5b655adb36c0d3c9",
    renderer: "c356ecf2f8af39bbe6185b9e7175e193f0f1c3c609f87191c1059cdcfda57bb6",
    maps: "48d8f5edbd3f2c1e0879201928a481ce2fe4bda9a817c0a77370733a66fd07c2"
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
