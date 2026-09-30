//
//  LayerMaskingExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Clipping a layer so it draws over land only, or over water only.
///
/// Every layer descriptor carries a ``LayerMaskConfiguration``.
/// ``LayerMaskConfiguration/land`` and ``LayerMaskConfiguration/water`` reference the
/// SDK's built-in water mask — `land` is that same mask inverted — so confining a
/// layer to one or the other is a single assignment before the layer is added, with
/// no second layer to style as a stencil.
///
/// The subject here is a Blue Marble raster served as a plain `{z}/{x}/{y}` image
/// source, which makes the clip easy to see against the basemap's own coastlines.
struct LayerMaskingExample: View {
    private enum Mask: String, CaseIterable, Identifiable {
        case land = "Land"
        case water = "Water"
        case both = "Both"

        var id: Self { self }

        var configuration: LayerMaskConfiguration {
            switch self {
            case .land: .land
            case .water: .water
            case .both: .none
            }
        }
    }

    @State private var mask: Mask = .land

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47.60621, longitude: 10), zoom: 3.0) { mapController, subscriptions in
            addBlueMarble(to: mapController, mask: mask)
        } overlay: { mapController in
            ExampleControlPanel {
                ExampleControlGroup(title: "Mask") {
                    Picker("Mask", selection: $mask) {
                        ForEach(Mask.allCases) { mask in
                            Text(mask.rawValue).tag(mask)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: mask) { newValue in
                        guard let mapController else { return }
                        // The mask is read when the layer is built, so re-add it.
                        mapController.removeLayer(id: "blue-marble-raster")
                        addBlueMarble(to: mapController, mask: newValue)
                    }
                }
            }
        }
    }

    private func addBlueMarble(to mapController: DemoMapController, mask: Mask) {
        let keys = AccessKeys.shared

        var marbleSource = ImageSourceDescriptor(id: "blue-marble")
        marbleSource.url = URL(
            string: "https://maps.api.xweather.com/\(keys.xweatherClientID)_\(keys.xweatherClientSecret)"
                + "/blue-marble/{z}/{x}/{y}/0@2x.png"
        )
        marbleSource.tileSize = 512

        var marbleLayer = RasterLayerDescriptor(
            id: "blue-marble-raster",
            source: marbleSource.id,
            paint: .init(opacity: 0.7, raster: .init())
        )
        marbleLayer.maskConfiguration = mask.configuration
        // A source with no transformer publishes no per-tile timing, so the layer
        // needs an interval mode to resolve a frame to draw.
        marbleLayer.timing.seriesMode = .interval

        do {
            // The layer is re-added when the mask changes; the source stays put.
            if !mapController.hasSource(id: marbleSource.id) {
                _ = try mapController.addSource(marbleSource)
            }
            _ = try mapController.addLayer(marbleLayer)
        } catch {
            print("Failed to add the Blue Marble raster layer: \(error)")
        }
    }
}

#Preview {
    LayerMaskingExample()
}
