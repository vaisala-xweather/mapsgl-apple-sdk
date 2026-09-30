//
//  FrostFreezeLayerExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Turning the temperatures layer into a purpose-built frost and freeze map.
///
/// Two paint properties do the work. A one-sided `drawRange` of `...2.22` °C throws
/// away everything above 36 °F, so the map shows only where frost is possible rather
/// than shading the whole continent. A color scale with `interpolate: false` then
/// paints the three agricultural categories as flat bands instead of a gradient:
///
/// - Frost: 32 °F to 36 °F (0 °C to 2.22 °C)
/// - Freeze: 28 °F to 32 °F (−2.22 °C to 0 °C)
/// - Hard freeze: at or below 28 °F (−2.22 °C)
///
/// The stock temperature legend would describe the original scale, so the config
/// carries a ``PointLegend`` naming the three categories instead.
struct FrostFreezeLayerExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 50, longitude: -70), zoom: 2) { mapController, subscriptions in
            var config = WeatherService.Temperatures(service: mapController.service)

            // Everything warmer than 36°F is simply not drawn.
            config.layer.paint.sample.drawRange = ...Self.frost
            config.layer.paint.sample.colorScale = .colorScale(
                ColorScaleOptions(
                    stops: [
                        ColorStop(-90, .fromString(Self.hardFreezeColor)),
                        ColorStop(Self.freeze, .fromString(Self.freezeColor)),
                        ColorStop(0, .fromString(Self.frostColor)),
                        ColorStop(Self.frost, .fromString(Self.frostColor))
                    ],
                    interval: 1,
                    interpolate: false
                )
            )

            config.legend = PointLegend(
                id: "temps-freeze",
                title: "Frost/Freeze",
                items: [
                    PointLegendItem(color: .fromString(Self.hardFreezeColor), label: "Hard Freeze"),
                    PointLegendItem(color: .fromString(Self.freezeColor), label: "Freeze"),
                    PointLegendItem(color: .fromString(Self.frostColor), label: "Frost")
                ]
            )
            config.presentation?.title = "Frost/Freeze"

            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .temperatures
                )
                try mapController.addWeatherLayer(config: config, beforeId: beforeId)
            } catch {
                print("Failed to add the frost/freeze layer: \(error)")
            }
        } overlay: { mapController in
            VStack(alignment: .trailing) {
                Spacer()
                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()
            }
        }
    }

    /// Category boundaries in Celsius, the unit the data arrives in.
    private static let frost = 2.22   // 36°F
    private static let freeze = -2.22 // 28°F

    private static let frostColor = "#73DAFC"
    private static let freezeColor = "#0046FF"
    private static let hardFreezeColor = "#992BFF"
}

#Preview {
    FrostFreezeLayerExample()
}
