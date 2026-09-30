//
//  CustomRasterLayerExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Drawing your own raster tiles: any `{z}/{x}/{y}` endpoint that returns images.
///
/// An ``ImageSourceDescriptor`` needs only a templated URL. Pair it with a
/// ``RasterLayerDescriptor`` naming that source's id, and add the source first —
/// `addLayer` resolves `source` by id. Only the URL's *path* is templated, so keep
/// the host literal: braces there make `URL(string:)` return nil.
///
/// A source configured this way has no transformer, so it publishes no per-tile
/// timing and renders as a single static frame that ignores the timeline. To animate
/// an Xweather product instead, build its source with
/// ``WeatherService/makeRasterSourceDescriptor(id:code:)``, which supplies the
/// metadata URL and transformer that drive a time series.
struct CustomRasterLayerExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 45.34880, longitude: 12.35666), zoom: 3.0) { mapController, subscriptions in
            let keys = AccessKeys.shared

            var satelliteSource = ImageSourceDescriptor(id: "custom-satellite")
            satelliteSource.url = URL(
                string: "https://maps.api.xweather.com/\(keys.xweatherClientID)_\(keys.xweatherClientSecret)"
                    + "/satellite-geocolor/{z}/{x}/{y}/0@2x.png"
            )
            satelliteSource.tileSize = 512

            var satelliteLayer = RasterLayerDescriptor(
                id: "custom-satellite-raster",
                source: satelliteSource.id,
                paint: .init(opacity: 0.7, raster: .init())
            )
            // Required: a layer left on the default `.none` series mode never builds a
            // time-series animator, so it never resolves an interval to draw and stays
            // blank even though its tiles load. Every built-in raster layer sets this.
            satelliteLayer.timing.seriesMode = .interval

            do {
                _ = try mapController.addSource(satelliteSource)
                _ = try mapController.addLayer(satelliteLayer)
            } catch {
                print("Failed to add the satellite raster layer: \(error)")
            }
        }
    }
}

#Preview {
    CustomRasterLayerExample()
}
