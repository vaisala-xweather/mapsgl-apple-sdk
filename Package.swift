// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let repositoryPath = "vaisala-xweather/mapsgl-apple-sdk"
let version: Version = "1.2.0-beta.1"
let xcframeworkChecksums = (
	core: "cf3475a81d7ee6b455839fd72015868b5890edc0b24e86d075ad5a3d92ad2415",
	renderer: "beca9d10405bbadf6e6c7760791b4ad6ab38d13ab037dfa6ee06905d82059b18",
	maps: "fa6ddbe5dae2d9f6e213030172c6070e961f300273409939f880126e08a3a8b5"
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
