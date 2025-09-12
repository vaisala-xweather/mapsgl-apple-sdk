// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.2.4"
let xcframeworkChecksums = (
	core: "6296b5eb19d2a70312448f6940b3e0a9b18a0c9c0d6cf9621b99a853b4544244",
	renderer: "4d6c3c8c4f2c43f6749f3ba8e71c1a6c52c3bc4f3f47fbaa72f8c82ca9ffb227",
	maps: "a864c998b22e6a682ce9aeace65ac1093f1fa5d7752f07439c93b184690e1d74"
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
                .product(name: "Turf", package: "turf-swift")
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
			]
		),
	]
)
