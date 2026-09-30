//
//  CustomVectorLayerExample.swift
//  Demo
//

import Combine
import MapsGLMaps
import SwiftUI

/// Rendering your own Mapbox Vector Tile source, styled from feature properties.
///
/// A ``VectorSourceDescriptor`` fetches the tiles; a ``FillLayerDescriptor`` draws the
/// polygons inside them. Rather than one flat color, the fill reads each feature's own
/// `COLOR` property through ``Expression/get(_:)``, so every alert type paints itself,
/// and an outline keeps adjacent alerts of the same color apart.
///
/// Weather alerts are already available as a built-in weather layer — the point here
/// is the pattern for a vector source MapsGL does not know about.
struct CustomVectorLayerExample: View {
    var body: some View {
        ExampleMapView(zoom: 3.5) { mapController, subscriptions in
            let keys = AccessKeys.shared

            var alertsSource = VectorSourceDescriptor(id: "custom-alerts")
            // `{z}`, `{x}` and `{y}` are substituted in the path. Keep the host
            // literal — braces there make `URL(string:)` return nil.
            alertsSource.url = URL(
                string: "https://maps.api.xweather.com/\(keys.xweatherClientID)_\(keys.xweatherClientSecret)"
                    + "/alerts/{z}/{x}/{y}/0.pbf"
            )

            // Each feature's COLOR property is a bare hex triplet ("00FF00"), so it
            // needs a leading "#" before it parses as a color.
            let alertColor = Expression.concat(["#", Expression.get("COLOR")])

            let alertsLayer = FillLayerDescriptor(
                id: "custom-alerts-fill",
                source: alertsSource.id,
                paint: .init(
                    fill: .init(
                        color: .expression(alertColor),
                        opacity: .constant(0.6)
                    ),
                    // A dark outline separates neighboring alerts that share a color,
                    // matching how the built-in `.alerts` layer draws them.
                    stroke: .init(
                        color: .constant(.black),
                        thickness: .constant(1)
                    )
                )
            )

            do {
                _ = try mapController.addSource(alertsSource)
                _ = try mapController.addLayer(alertsLayer)
            } catch {
                print("Failed to add the alerts vector layer: \(error)")
            }
        }
    }
}

#Preview {
    CustomVectorLayerExample()
}
