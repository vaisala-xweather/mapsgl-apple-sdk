//
//  QueryLayerAPIGeoJSONExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Labelling your own points with values sampled from a weather layer.
///
/// A ``DataQueryLayerDescriptor`` fetches no data of its own. It takes a point source
/// and a `queryLayerCode`, samples that weather layer at each point, and binds the
/// result to the `dataValue` variable its text can read. Here the points are the 100
/// most populous US cities, pulled from the Xweather places endpoint as GeoJSON.
///
/// ``Expression/toUnit(_:)`` formats the sampled value in whatever units the map is
/// displaying, so the labels follow `setUnits(_:)` without any work here. The queried
/// layer has to be on the map — it is the thing being sampled.
struct QueryLayerAPIGeoJSONExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -93), zoom: 4) { mapController, subscriptions in
            let keys = AccessKeys.shared

            var citiesSource = GeoJSONSourceDescriptor(id: "cities")
            citiesSource.url = URL(
                string: "https://data.api.xweather.com/places/search"
                    + "?query=country:us,name:!NULL&sort=pop:-1&limit=100&format=geojson"
                    + "&client_id=\(keys.xweatherClientID)&client_secret=\(keys.xweatherClientSecret)"
            )

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
                        )
                    ],
                    symbol: .init(allowOverlap: true, fadeOpacity: false)
                ),
                queryLayerCode: .temperatures,
                // A GeoJSON source has no named sub-layers, unlike a vector tileset.
                sourceLayer: nil
            )

            do {
                // The layer being sampled has to be present, though it need not be visible.
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .temperatures
                )
                try mapController.addWeatherLayer(for: .temperatures, beforeId: beforeId)

                // The values would otherwise fight the basemap's own place names.
                DemoMapProvider.setPlaceLabelLayersVisible(false, for: mapController)

                _ = try mapController.addSource(citiesSource)
                _ = try mapController.addLayer(citiesText)
            } catch {
                print("Failed to add the city temperature labels: \(error)")
            }
        }
    }
}

#Preview {
    QueryLayerAPIGeoJSONExample()
}
