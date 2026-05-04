// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.6.0"
let xcframeworkChecksums = (
    core: "1cbd89e327073c2f29437cde901484517319151fe88d9a43551696760c9306f6",
    renderer: "ed4a6de638ad1b5ff4a1c2899921460b054b2b860c4a4a49d9ca06ec51e67018",
    maps: "a0f53f5f396e84ae30f4e8dedac6b0f42dd9acb6edc659c0bfe95dcdec8f6b28"
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
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", from: "11.0.0"),
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
