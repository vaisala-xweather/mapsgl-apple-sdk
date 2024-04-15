// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let version: Version = "1.0.0-beta.4"
let xcframeworkChecksums = (
	core: "06801f365044d580636631a1be9facc9b6f9aae6cab13dd7068edc4578ac50b3",
	renderer: "c8a7106a90628641563100ffd8c844d394f0e9df0f81d4c5f3b1ecbdbe972f20",
	maps: "179173cae8b754a5cdbedc3695106946da0e13ddc6dc63043b190a71df7a7bff",
	mapbox: "e9408a68d49261f7f9c3f602011943911f83dc9ee1dc1b5f329a7643c387d526"
)


let package = Package(
	name: "MapsGL",
	platforms: [ .iOS(.v16), .macCatalyst(.v16), .visionOS(.v1) ],
	products: [
		.library(name: "MapsGL", targets: [
			"MapsGLRendererWrapper",
			"MapsGLMapsWrapper",
			"MapsGLMapboxWrapper",
		]),
	],
	dependencies: [
		.package(url: "https://github.com/mapbox/mapbox-maps-ios.git", from: "11.0.0"),
	],
	targets: [
		.binaryTarget(name: "MapsGLCore",
			url: "https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases/download/v\(version)/MapsGLCore.xcframework.zip",
			checksum: xcframeworkChecksums.core
		),
		
		.target(name: "MapsGLRendererWrapper",
			dependencies: [
				"MapsGLCore",
				"MapsGLRenderer",
			]
		),
		.binaryTarget(name: "MapsGLRenderer",
			url: "https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases/download/v\(version)/MapsGLRenderer.xcframework.zip",
			checksum: xcframeworkChecksums.renderer
		),
		
		.target(name: "MapsGLMapsWrapper",
			dependencies: [
				"MapsGLCore",
				"MapsGLRenderer",
				"MapsGLMaps",
			]
		),
		.binaryTarget(name: "MapsGLMaps",
			url: "https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases/download/v\(version)/MapsGLMaps.xcframework.zip",
			checksum: xcframeworkChecksums.maps
		),
		
		.target(name: "MapsGLMapboxWrapper",
			dependencies: [
				"MapsGLMaps",
				"MapsGLMapbox",
				.product(name: "MapboxMaps", package: "mapbox-maps-ios"),
			]
		),
		.binaryTarget(name: "MapsGLMapbox",
			url: "https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases/download/v\(version)/MapsGLMapbox.xcframework.zip",
			checksum: xcframeworkChecksums.mapbox
		),
	]
)
