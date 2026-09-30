//
//  QueryLayerStaticGeoJSONExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Sampling a weather layer at points you supply yourself.
///
/// Same mechanism as querying an API feed, with the points written inline instead —
/// a fixed set of sites, your own stations, wherever you need a reading. The layer
/// draws two text elements per point: the sampled wind speed, and the place name
/// from the feature's own properties beneath it.
///
/// `quality` on the queried layer decides how finely its data is sampled. Raising it
/// to `.high` matters at close zoom, where neighbouring points would otherwise land
/// in the same cell and report the same value.
struct QueryLayerStaticGeoJSONExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47.60621, longitude: -122.33207), zoom: 8) { mapController, subscriptions in
            var citiesSource = GeoJSONSourceDescriptor(id: "cities")
            citiesSource.data = .string(Self.pugetSoundCities)

            let citiesText = DataQueryLayerDescriptor(
                id: "cities-text",
                source: citiesSource.id,
                paint: .init(
                    text: [
                        .init(
                            value: .expression(Expression.toUnit(Expression.variable("dataValue"))),
                            size: .constant(20),
                            weight: .constant("bold"),
                            color: .constant(.black),
                            outlineColor: .constant(.white)
                        ),
                        .init(
                            value: .expression(Expression.get("place.name")),
                            size: .constant(12),
                            color: .constant(.black),
                            outlineColor: .constant(.white),
                            anchor: .constant(.top),
                            offset: .constant(AnchorOffset(x: 0, y: 14))
                        )
                    ],
                    symbol: .init(allowOverlap: true, fadeOpacity: false)
                ),
                queryLayerCode: .windSpeeds,
                sourceLayer: nil
            )

            do {
                var winds = WeatherService.WindSpeeds(service: mapController.service)
                winds.layer.quality = .high

                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .windSpeeds
                )
                try mapController.addWeatherLayer(config: winds, beforeId: beforeId)

                DemoMapProvider.setPlaceLabelLayersVisible(false, for: mapController)

                _ = try mapController.addSource(citiesSource)
                _ = try mapController.addLayer(citiesText)
            } catch {
                print("Failed to add the wind speed labels: \(error)")
            }
        }
    }

    /// Twenty cities around Puget Sound, each carrying a `place.name` property.
    private static let pugetSoundCities: String = {
        let cities: [(String, Double, Double)] = [
            ("Seattle", -122.33207, 47.60621),
            ("Tacoma", -122.44429, 47.25288),
            ("Bellevue", -122.20068, 47.61038),
            ("Kent", -122.23484, 47.38093),
            ("Everett", -122.20208, 47.97898),
            ("Renton", -122.21707, 47.48288),
            ("Federal Way", -122.31262, 47.32232),
            ("Kirkland", -122.20874, 47.68149),
            ("Auburn", -122.22845, 47.30732),
            ("Marysville", -122.17708, 48.05176),
            ("Redmond", -122.12151, 47.67399),
            ("Lakewood", -122.51846, 47.17176),
            ("Shoreline", -122.34152, 47.75565),
            ("South Hill", -122.27012, 47.14121),
            ("Sammamish", -122.0804, 47.64177),
            ("Burien", -122.34679, 47.47038),
            ("Olympia", -122.90169, 47.04491),
            ("Lacey", -122.82319, 47.03426),
            ("Bothell", -122.2054, 47.76232)
        ]

        let features = cities.map { name, longitude, latitude in
            """
            {
                "type": "Feature",
                "geometry": { "type": "Point", "coordinates": [\(longitude), \(latitude)] },
                "properties": { "place": { "name": "\(name)", "state": "WA", "country": "US" } }
            }
            """
        }

        return """
        { "type": "FeatureCollection", "features": [\(features.joined(separator: ","))] }
        """
    }()
}

#Preview {
    QueryLayerStaticGeoJSONExample()
}
