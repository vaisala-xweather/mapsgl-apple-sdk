# MapsGL SDK for Apple Platforms

<img src="images/mapsgl-apple-sdk-intro.webp" alt="MapsGL Demo screenshot"/>

[![Release version](https://img.shields.io/github/v/release/vaisala-xweather/mapsgl-apple-sdk.svg?label=Release&labelColor=2D323A&color=4ed9c2&include_prereleases)](https://github.com/vaisala-xweather/mapsgl-apple-sdk/releases)
[![Swift workflow badge](https://github.com/vaisala-xweather/mapsgl-apple-sdk/actions/workflows/xcodebuild-Demo.yml/badge.svg)](https://github.com/vaisala-xweather/mapsgl-apple-sdk/actions)
[![Swift Package Manager supported](https://img.shields.io/badge/Swift_Package_Manager-supported-blue.svg?labelColor=2D323A)](https://swiftpackageindex.com/vaisala-xweather/mapsgl-apple-sdk)
[![CocoaPods supported](https://img.shields.io/badge/CocoaPods-supported-blue.svg?labelColor=2D323A)](https://cocoapods.org/pods/MapsGL)
[![Carthage supported](https://img.shields.io/badge/Carthage-supported-blue.svg?labelColor=2D323A)](https://github.com/Carthage/Carthage)


## Overview

MapsGL Apple SDK is a powerful mapping library designed for iOS developers. It enables the integration of MapsGL's rich mapping features into iOS applications, providing a seamless and interactive user experience.

## Features

- Visualizing real-time weather and geospatial data
- High-performance layer rendering with Metal
- Customizable presentation and styling of weather and geospatial information client-side

## Getting Started

We have [in-depth installation and setup guides](http://www.xweather.com/docs/mapsgl-apple-sdk) available for you to get started using the MapsGL SDK for Apple platforms, using Swift Package Manager, Carthage, or direct Xcode integration of MapsGL's xcframeworks.

> [!NOTE]
> When consuming this repo as a Swift Package, the current branch is the Mapbox channel. If you need the MapLibre channel instead, use the [maplibre branch](https://github.com/vaisala-xweather/mapsgl-apple-sdk/tree/maplibre).

The following are basic instructions to run the included Demo application, which provides a simple template for integrating MapsGL with your app.

## Running the Demo App

The MapsGL Apple SDK includes a demo application that showcases the capabilities of the SDK. To run the demo application, follow these steps:

### Prerequisites

- Xcode 26 or later
- An Apple Developer account
- An iOS 16+ device (or Xcode's iOS Simulator)
- An Xweather account. We offer a [free developer account](https://www.aerisweather.com/signup/developer/) for you to give our weather API a test drive.
- A Mapbox account

### Steps to Run

1. Log into your Xweather account, and from [your account's Apps page](https://account.aerisweather.com/account/apps), create a new application for the MapsGL Demo app. Make note of the application's Xweather MapsGL ID and secret; you'll need them in step 5.
2. The Demo application on this branch relies on Mapbox, so you'll need to log into or create a Mapbox account and follow the initial setup portion of [Mapbox Maps SDK for iOS's installation instructions](https://docs.mapbox.com/ios/maps/guides/install/):
   - Follow the "Configure credentials" instructions to get a Mapbox public access token and a secret access token.
   - Follow the "Configure your secret token" instructions using your Mapbox secret access token in order to be able to download the Mapbox SDK via Swift Package Manager in the Demo app.
   - Make note of your Mapbox public access token; you'll need it in step 5.
3. Clone the repository to your local machine:
   ```
   git clone https://github.com/vaisala-xweather/mapsgl-apple-sdk.git
   ```
4. Open `Demo.xcodeproj` in Xcode.
5. Before running the demo, you will need to configure the access keys for MapsGL and Mapbox.
   - Build the Demo scheme once to auto-create a fresh `Config/AccessKeys.plist` file, then fill in `MapboxAccessToken`, `XweatherClientID`, and `XweatherClientSecret`.
6. Select your target device or simulator, then build and run.

### Exploring the Demo

The demo opens on a browser of focused examples, each one a single Swift file under
`Demo/Examples/` that you can read start to finish and lift into your own app. They are
grouped into:

- **Explore** — the weather layer explorer: every layer the SDK ships, with timeline
  playback, legends and the data inspector.
- **Getting Started** — a minimal weather map, and the same map driven from UIKit.
- **Styling Weather Layers** — color scales, draw ranges and particle settings on the
  built-in layers, including purpose-built maps such as frost and freeze categories.
- **Features & Filtering** — styling and filtering vector layers by each feature's own
  properties, on alerts and lightning.
- **Animation** — timeline playback, changing the animation range, and preloading frames.
- **Legends, Units & Readouts** — the legend and data inspector controls, the units
  values display in, and labelling your own points with sampled layer values.
- **Your Own Data** — your own raster, vector and GeoJSON sources, and masking a layer
  to land.

Examples share a small scaffold in `Demo/Examples/Scaffold/` — `ExampleMapView` and its
overlay chrome — so each example file stays about one API. The Mapbox
specifics live behind `DemoMapProvider.swift`.

To start on one example rather than the list — handy while you are editing it — pass
its slug as a launch argument, either in the scheme's run arguments or with:

```
xcrun simctl launch booted com.xweather.MapsGLDemo -example custom-radar-colors
```

Every example is also published, with a screenshot, at
[xweather.com/docs/mapsgl-apple-sdk/examples](https://www.xweather.com/docs/mapsgl-apple-sdk/examples).

## Troubleshooting

If you encounter any issues while running the demo application, ensure that:

- Your Xcode and iOS versions meet the prerequisites.
- You have correctly configured `Config/AccessKeys.plist` with valid API keys.
- There are no build errors related to missing dependencies or configurations.

For further assistance, please refer to the [documentation](http://www.xweather.com/docs/mapsgl-apple-sdk) or contact [support](https://www.xweather.com/support).
