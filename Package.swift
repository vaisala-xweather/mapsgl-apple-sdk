// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.1.0-beta.2"
let xcframeworkChecksums = (
	core: "2002d6534c38c6fa64f6a4b8a77582aebe6c8e47a828590d88673566290fd119",
	renderer: "b9a8279fc95fff51c857461390ed74086bc1c39e3ef1bb5792870b87720dc6f9",
	maps: "cb72eb94c0239f1dc9f7ede0672c68d9425693a29c8bcfa721653a35950963cc"
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
