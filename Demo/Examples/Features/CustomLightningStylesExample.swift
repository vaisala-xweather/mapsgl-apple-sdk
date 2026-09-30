//
//  CustomLightningStylesExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Fading lightning strikes out as they age.
///
/// Each strike feature carries an `age` in seconds. ``Expression/step(_:_:)`` turns
/// that into discrete bands — a step expression takes an initial result with no
/// value, then one result per threshold — so a strike from the last minute reads as
/// bright white and a ten-minute-old one has all but vanished.
///
/// Color and opacity step on the same property. Doing it twice rather than baking the
/// alpha into the colors keeps the two independently adjustable, and the stroke steps
/// alongside the fill so a ring at full strength doesn't hold every strike at the
/// brightness of a fresh one.
struct CustomLightningStylesExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 30, longitude: -84.5), zoom: 5) { mapController, subscriptions in
            var config = WeatherService.LightningStrikes(service: mapController.service)

            config.layer.paint.fill.color = .expression(
                Expression.step(Self.age, [
                    .init(value: nil, result: "#ffffff"),
                    .init(value: 61, result: "rgba(255, 255, 255, 0.7)"),
                    .init(value: 301, result: "rgba(255, 255, 255, 0.5)"),
                    .init(value: 601, result: "rgba(255, 255, 255, 0.3)")
                ])
            )
            config.layer.paint.fill.opacity = .expression(Self.fadeByAge)
            config.layer.paint.stroke.color = .constant(.white)
            config.layer.paint.stroke.opacity = .expression(Self.fadeByAge)
            config.layer.paint.stroke.thickness = .constant(1)
            config.layer.paint.circle.radius = .constant(5)

            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .lightningStrikes
                )
                try mapController.addWeatherLayer(config: config, beforeId: beforeId)
            } catch {
                print("Failed to add the lightning strikes layer: \(error)")
            }
        }
    }

    /// Seconds since the strike, defaulting to zero for a feature that carries none.
    private static let age = Expression.coalesce([Expression.get("age"), 0])

    /// Full strength under a minute, then stepped down at five and ten.
    private static let fadeByAge = Expression.step(age, [
        .init(value: nil, result: 1.0),
        .init(value: 61, result: 0.8),
        .init(value: 301, result: 0.6),
        .init(value: 601, result: 0.4)
    ])
}

#Preview {
    CustomLightningStylesExample()
}
