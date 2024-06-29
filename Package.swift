// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let version: Version = "1.0.0"
let xcframeworkChecksums = (
	core: "7b51f89e2521cde5426818c8f1368eee67ee90a2337b7b80853c2b57d51d911b",
	renderer: "d1483630e0a190e81f2a8d7aafdac71a4463b5ddd2af7cc570300ed2b8f96890",
	maps: "d43e6325cc880e5b604bc674ff87fd29eb4705f54eee126bf59cdd8065f6679b",
	mapbox: "53b5a9adb9fe42b1e5382963c6ce61d1acb18635b93b8a3b9ef002b6ffde25fb"
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
