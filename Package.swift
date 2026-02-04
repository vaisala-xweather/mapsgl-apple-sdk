// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.4.0"
let xcframeworkChecksums = (
	core: "11529475a6e08b63b0cbbda676293b84ed97e6a7186aa3f236d23753fcdf49ac",
	renderer: "034cb21a00b96077453675190446bf4102de82568a18185f0efb528c0d76bd60",
	maps: "8c3cea31e1014e3c73b704d1510e4c800c3f98645c7009c94e7e05f0f0b82679"
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
