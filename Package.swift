// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let version: Version = "1.0.1"
let xcframeworkChecksums = (
	core: "c78e7cf0963d1d346e22f2560dce3462ef338c8ae498d9bdff0de7c3d4f67fd4",
	renderer: "e9864eaae677e45f8008ea8dec1a33eb82da65ddf7e3d65cb22bc26a18096d58",
	maps: "94bcc1129dd8424ef90baed22c55345008aac89dc80361f6bd9bccae6642265a",
	mapbox: "fcfdf78ed5b34bf07f51ab4eef0ef5b78771a7da9f8f256cb3545ea24b544f2e"
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
