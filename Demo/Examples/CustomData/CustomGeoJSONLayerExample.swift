//
//  CustomGeoJSONLayerExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Drawing your own GeoJSON geometry, with two style layers over one source.
///
/// A ``GeoJSONSourceDescriptor`` takes its features inline through
/// ``GeoJSONSourceData/string(_:)`` as easily as from a URL, so a shape you already
/// have needs no hosting. Any number of layers can then reference that one source by
/// id: here a ``FillLayerDescriptor`` paints the polygon and a
/// ``LineLayerDescriptor`` traces a thicker outline along its edges, which reads far
/// better at low zoom than a fill alone.
struct CustomGeoJSONLayerExample: View {
    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -8), zoom: 5) { mapController, subscriptions in
            var regionSource = GeoJSONSourceDescriptor(id: "country-region")
            regionSource.data = .string(Self.portugalGeoJSON)

            // Fill the polygon region.
            let regionFill = FillLayerDescriptor(
                id: "region-fill",
                source: regionSource.id,
                paint: .init(
                    fill: .init(
                        color: .constant(.red),
                        opacity: .constant(0.5)
                    )
                )
            )

            // Add a thicker outline to the region.
            let regionOutline = LineLayerDescriptor(
                id: "region-outline",
                source: regionSource.id,
                paint: .init(
                    stroke: .init(
                        color: .constant(.red),
                        thickness: .constant(5)
                    )
                )
            )

            do {
                _ = try mapController.addSource(regionSource)
                _ = try mapController.addLayer(regionFill)
                _ = try mapController.addLayer(regionOutline)
            } catch {
                print("Failed to add the region GeoJSON layers: \(error)")
            }
        }
    }

    /// One polygon feature outlining Portugal.
    private static let portugalGeoJSON = """
    {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {
                    "type": "Sovereign country",
                    "name": "Portugal",
                    "continent": "Europe",
                    "region_un": "Europe",
                    "subregion": "Southern Europe",
                    "region_wb": "Europe & Central Asia"
                },
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [
                        [
                            [-9.034817674180246, 41.88057058365967],
                            [-8.67194576662672, 42.13468943945496],
                            [-8.263856980817792, 42.28046865495034],
                            [-8.013174607769912, 41.790886135417125],
                            [-7.422512986673795, 41.79207469335983],
                            [-7.251308966490824, 41.91834605566505],
                            [-6.668605515967656, 41.883386949219584],
                            [-6.389087693700915, 41.381815497394655],
                            [-6.851126674822552, 41.11108266861753],
                            [-6.864019944679385, 40.33087189387483],
                            [-7.026413133156595, 40.184524237624245],
                            [-7.066591559263529, 39.71189158788277],
                            [-7.498632371439725, 39.62957103124181],
                            [-7.098036668313128, 39.03007274022378],
                            [-7.374092169616318, 38.37305858006492],
                            [-7.029281175148796, 38.07576406508977],
                            [-7.166507941099865, 37.803894354802225],
                            [-7.537105475281024, 37.42890432387623],
                            [-7.453725551778092, 37.09778758396607],
                            [-7.855613165711985, 36.83826854099627],
                            [-8.382816127953689, 36.97888011326246],
                            [-8.898856980820327, 36.86880931248078],
                            [-8.746101446965554, 37.65134552667661],
                            [-8.839997524439879, 38.26624339451761],
                            [-9.287463751655224, 38.3584858261586],
                            [-9.526570603869715, 38.73742910415491],
                            [-9.446988898140232, 39.39206614842837],
                            [-9.048305223008427, 39.75509308527877],
                            [-8.977353481471681, 40.15930613866581],
                            [-8.768684047877102, 40.76063894303019],
                            [-8.79085323733031, 41.18433401139126],
                            [-8.99078935386757, 41.54345937760364],
                            [-9.034817674180246, 41.88057058365967]
                        ]
                    ]
                }
            }
        ]
    }
    """
}

#Preview {
    CustomGeoJSONLayerExample()
}
