// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let version: Version = "1.0.0-beta.1"
let xcframeworkChecksums = (
	core: "0c21313c6e713355e0cd3248600f8b5cdf242a30db94e4769de2ccc8a56c6de0",
	maps: "b3e0338c1e79c1470958fd450778685b4d1e5658b6be15b7d727727320454108",
	mapbox: "6d4bb10f6d03d49e75b4fe76daeae13b483eb4b9665ab17075d40ab274b998db"
)


let package = Package(
	name: "MapsGL",
	platforms: [ .iOS(.v16), .macCatalyst(.v16), ],
	products: [
		.library(name: "MapsGL", targets: [
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
		
		.target(name: "MapsGLMapsWrapper",
			dependencies: [
				"MapsGLCore",
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
