//
//  WindSpeedCategoriesExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Turning wind speeds into named categories rather than a continuous field.
///
/// The same two properties that build a frost map build this one: a one-sided
/// `drawRange` starting at 15 mph hides the calm majority of the map, and a color
/// scale with `interpolate: false` paints each category as a flat band.
///
/// Wind data arrives in metres per second, so the thresholds are written in miles per
/// hour and converted — a draw range and its color stops are always in the data's own
/// units, never the map's display units.
struct WindSpeedCategoriesExample: View {
    private struct Category {
        let milesPerHour: Double
        let color: String
        let label: String
    }

    private static let categories: [Category] = [
        .init(milesPerHour: 15, color: "#AED9FE", label: "Breezy"),
        .init(milesPerHour: 25, color: "#FFDF2C", label: "Windy"),
        .init(milesPerHour: 39, color: "#FF9503", label: "Gale / Tropical Storm Force"),
        .init(milesPerHour: 55, color: "#DB2500", label: "Storm / Severe Gale"),
        .init(milesPerHour: 75, color: "#D802E0", label: "Hurricane Force")
    ]

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47.60621, longitude: -122.33207), zoom: 3) { mapController, subscriptions in
            var config = WeatherService.WindSpeeds(service: mapController.service)

            config.layer.paint.sample.drawRange = Self.metersPerSecond(15)...
            config.layer.paint.sample.colorScale = .colorScale(
                ColorScaleOptions(
                    stops: Self.categories.map {
                        ColorStop(Self.metersPerSecond($0.milesPerHour), .fromString($0.color))
                    },
                    // The range the stops are placed against. Leaving it off would fall
                    // back to the dataset's own, which for wind runs negative — these are
                    // the U and V components — and would push every real speed into the
                    // top half of the scale.
                    range: 0...Self.metersPerSecond(120),
                    interpolate: false
                )
            )

            config.legend = PointLegend(
                id: "wind-speed-categories",
                title: "Wind Speed",
                items: Self.categories.map {
                    PointLegendItem(color: .fromString($0.color), label: $0.label)
                }
            )

            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .windSpeeds
                )
                try mapController.addWeatherLayer(config: config, beforeId: beforeId)
            } catch {
                print("Failed to add the wind speeds layer: \(error)")
            }
        } overlay: { mapController in
            VStack(alignment: .trailing) {
                Spacer()
                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame(maxHeight: 260)
            }
        }
    }

    private static func metersPerSecond(_ milesPerHour: Double) -> Double {
        Measurement(value: milesPerHour, unit: UnitSpeed.milesPerHour)
            .converted(to: .metersPerSecond)
            .value
    }
}

#Preview {
    WindSpeedCategoriesExample()
}
