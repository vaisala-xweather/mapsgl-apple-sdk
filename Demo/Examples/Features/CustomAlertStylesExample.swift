//
//  CustomAlertStylesExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Coloring alert polygons by severity rather than by alert type.
///
/// The built-in `.alerts` layer paints each polygon its official NWS color, taken
/// from the feature's own `COLOR` property. Swapping that for a
/// ``Expression/switchCase(_:fallback:)`` over the human-readable `ADVISORY` string
/// collapses a hundred alert types into four bands, which is what a reader usually
/// wants: warnings, then watches, then advisories, then statements.
///
/// The same expression drives fill and stroke, so a polygon and its edge always
/// agree. Anything the cases miss falls back to the feature's own color.
struct CustomAlertStylesExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40.60621, longitude: -96.33207), zoom: 3) { mapController, subscriptions in
            var config = WeatherService.Alerts(service: mapController.service)

            config.layer.paint.fill.color = .expression(Self.alertColor)
            config.layer.paint.fill.opacity = .constant(0.5)
            config.layer.paint.stroke = .init(
                color: .expression(Self.alertColor),
                opacity: .constant(1)
            )

            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .alerts
                )
                try mapController.addWeatherLayer(config: config, beforeId: beforeId)
            } catch {
                print("Failed to add the alerts layer: \(error)")
            }
        }
    }

    /// Cases are tested in order, so the most severe match wins.
    ///
    /// `regex` takes a pattern and an input; there is no separate flags argument, so
    /// case-insensitivity is written into the pattern as `(?i)`.
    private static let alertColor = Expression.switchCase(
        [
            (condition: Self.advisoryMatches("warning|extreme"), result: "#df1616"),
            (condition: Self.advisoryMatches("watch|severe"), result: "#ff9600"),
            (condition: Self.advisoryMatches("advisory|moderate"), result: "#009ac8"),
            (condition: Self.advisoryMatches("statement|alert|minor"), result: "#808080")
        ],
        fallback: Expression.coalesce([
            Expression.concat(["#", Expression.get("COLOR")]),
            "#000000"
        ])
    )

    private static func advisoryMatches(_ pattern: String) -> MapsGLMaps.Expression {
        Expression(["regex", "(?i)\(pattern)", Expression.get("ADVISORY")])
    }
}

#Preview {
    CustomAlertStylesExample()
}
