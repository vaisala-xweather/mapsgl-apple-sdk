// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.0.2"
let xcframeworkChecksums = (
	core: "cee22caae7f36de31aed86a64e469351c61bb5dab809e5c43473a646509200c6",
	renderer: "dc050130d8e228fbb3a77ec796cde4b4ece5115cf498a7969ea3e5531636f995",
	maps: "87e80609e2e9d5cbbf8a07142e77977cbeb12474ea1b3282342746e1a13f1448"
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
		.package(url: "https://github.com/mapbox/mapbox-maps-ios.git", "11.0.0"..<"11.5.0"),
	],
	targets: [
		.binaryTarget(name: "MapsGLCore",
			url: "https://github.com/\(repositoryPath)/releases/download/v\(version)/MapsGLCore.xcframework.zip",
			checksum: xcframeworkChecksums.core
		),
		
		.target(name: "MapsGLRendererWrapper",
			dependencies: [
				"MapsGLCore",
				"MapsGLRenderer",
			]
		),
		.binaryTarget(name: "MapsGLRenderer",
			url: "https://github.com/\(repositoryPath)/releases/download/v\(version)/MapsGLRenderer.xcframework.zip",
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
			url: "https://github.com/\(repositoryPath)/releases/download/v\(version)/MapsGLMaps.xcframework.zip",
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
