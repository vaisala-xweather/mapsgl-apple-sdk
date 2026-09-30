//
//  CustomHeatIndexLegendExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Relabelling a layer's legend without touching its colors.
///
/// A weather layer's ``WeatherLayerConfiguration/legend`` is part of its config, so
/// it can be adjusted before the layer is added. Heat index ships a
/// ``BarLegend`` labelled with the temperatures it maps; replacing its
/// ``BarLegendLabels/values`` with ``BarLegendLabels/Values/labels(_:)`` puts words
/// where the numbers were, which suits an index whose meaning matters more than its
/// magnitude.
///
/// Setting `normalized` makes those label positions run `0...1` across the bar rather
/// than naming values in the data's own units, so the same three labels hold however
/// the underlying scale is redefined.
struct CustomHeatIndexLegendExample: View {
    private enum Labels: String, CaseIterable, Identifiable {
        case values = "Values"
        case categories = "Categories"

        var id: Self { self }
    }

    @State private var labels: Labels = .categories

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 34, longitude: -93), zoom: 3) { mapController, subscriptions in
            addHeatIndex(to: mapController, labels: labels)
        } overlay: { mapController in
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()

                VStack(alignment: .leading, spacing: 14) {
                    ExampleControlGroup(title: "Legend labels") {
                        Picker("Legend labels", selection: $labels) {
                            ForEach(Labels.allCases) { labels in
                                Text(labels.rawValue).tag(labels)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: labels) { newValue in
                            guard let mapController else { return }
                            mapController.removeWeatherLayer(for: .heatIndex)
                            addHeatIndex(to: mapController, labels: newValue)
                        }
                    }
                }
                .exampleControlSurface()
            }
        }
    }

    private func addHeatIndex(to mapController: DemoMapController, labels: Labels) {
        var config = WeatherService.HeatIndex(service: mapController.service)

        if labels == .categories, let legend = config.legend as? BarLegend<UnitTemperature> {
            var updated = legend
            updated.items = legend.items.map { item in
                var item = item
                item.labels.normalized = true
                item.labels.values = .labels { _ in
                    [(0, "Uncomfortable"), (0.5, "Hot"), (1, "Dangerous")]
                }
                return item
            }
            config.legend = updated
        }

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .heatIndex
            )
            try mapController.addWeatherLayer(config: config, beforeId: beforeId)
        } catch {
            print("Failed to add the heat index layer: \(error)")
        }
    }
}

#Preview {
    CustomHeatIndexLegendExample()
}
