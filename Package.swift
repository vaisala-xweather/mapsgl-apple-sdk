// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let version: Version = "1.0.2"
let xcframeworkChecksums = (
	core: "971f2cd7ebec1eed1f683821c9942e89997c11b1d5fe62ee328ca4dead35b76b",
	renderer: "1c14b223e809b58b7c08c88e134cd2482cce67c0ff3f745706cb02c7dd8ea536",
	maps: "544d19a152c10e6d500929080d590091382f7f2191b3e2fd835033b69f5fd96d",
	mapbox: "9e3f7c32f5c77f1628d6b2964ef3b1384e6fcac9d91aea0531082dad1e7463ac"
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
