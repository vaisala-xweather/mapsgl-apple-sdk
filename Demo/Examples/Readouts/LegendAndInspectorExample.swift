//
//  LegendAndInspectorExample.swift
//  Demo
//

import Combine
import MapsGLMaps
import SwiftUI

/// The two controls the SDK ships for reading values off a map.
///
/// ``LegendControlView`` renders a legend for every weather layer currently on the
/// map, restyling itself as layers are added or removed and as units change.
/// `dataInspectorOverlay(mapControllerProvider:)` adds the tap-to-inspect callout.
/// Both take a closure rather than the controller itself, since the controller only
/// exists after the map's first load.
struct LegendAndInspectorExample: View {
    @State private var showsLegend = true

    var body: some View {
        ExampleMapView(zoom: 4.0) { mapController, subscriptions in
            for code in [WeatherService.LayerCode.temperatures, .windParticles] {
                do {
                    let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                        for: mapController,
                        layerCode: code
                    )
                    try mapController.addWeatherLayer(for: code, beforeId: beforeId)
                } catch {
                    print("Failed to add \(code.rawValue): \(error)")
                }
            }
        } overlay: { mapController in
            ZStack {
                // The inspector positions its callout inside whatever view it is
                // attached to, so that view has to share the map's coordinate space.
                // Without `ignoresSafeArea` this layer starts below the status bar and
                // every callout lands that far under the tap.
                Color.clear
                    .dataInspectorOverlay(mapControllerProvider: { mapController })
                    .ignoresSafeArea()

                // One `Spacer` for the whole stack. `ExampleControlPanel` carries its
                // own, so nesting it here would leave two competing for the space and
                // shove the legend to the top of the screen.
                VStack(alignment: .trailing, spacing: 8) {
                    Spacer()

                    if showsLegend {
                        LegendControlView(mapControllerProvider: { mapController })
                            .exampleLegendFrame()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Legend", isOn: $showsLegend)
                            .font(.subheadline)

                        Text("Tap the map to inspect values at that point.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .exampleControlSurface()
                }
            }
        }
    }

}

#Preview {
    LegendAndInspectorExample()
}
