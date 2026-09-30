//
//  AdjustDrawRangeExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Drawing only part of a layer's data range, adjusted live.
///
/// `sample.drawRange` clips which values a sample layer paints at all — values
/// outside it are left transparent rather than clamped to the end colors. Narrowing
/// it isolates a band of interest, like showing only freezing temperatures, without
/// touching the color scale.
///
/// The sliders read in Fahrenheit because that is what the map is displaying, but the
/// range is set in Celsius: draw ranges are always in the data's own units, which for
/// every MapsGL dataset means metric.
struct AdjustDrawRangeExample: View {
    /// In Fahrenheit, matching what the sliders show.
    @State private var lowerBound: Double = -40
    @State private var upperBound: Double = 50

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 39, longitude: -80), zoom: 2) { mapController, subscriptions in
            addTemperatures(to: mapController)
        } overlay: { mapController in
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()

                VStack(alignment: .leading, spacing: 14) {
                    ExampleControlGroup(title: "Draw range") {
                        VStack(alignment: .leading, spacing: 8) {
                            slider("Min", value: $lowerBound, mapController: mapController)
                            slider("Max", value: $upperBound, mapController: mapController)
                        }
                    }
                }
                .exampleControlSurface()
            }
        }
    }

    /// Both sliders span this, fixed. Bounding one by the other's current value would
    /// rescale its track as the other moved, so the same position under the thumb would
    /// mean a different temperature from one drag to the next.
    private static let sliderRange: ClosedRange<Double> = -60...120

    @ViewBuilder
    private func slider(
        _ title: String,
        value: Binding<Double>,
        mapController: DemoMapController?
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            Slider(value: value, in: Self.sliderRange) { isEditing in
                guard isEditing == false, let mapController else { return }
                // Re-add rather than mutate: paint is captured when the layer is built.
                mapController.removeWeatherLayer(for: .temperatures)
                addTemperatures(to: mapController)
            }

            Text("\(Int(value.wrappedValue))°F")
                .font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)
        }
    }

    private func addTemperatures(to mapController: DemoMapController) {
        var config = WeatherService.Temperatures(service: mapController.service)
        // The sliders share one scale and can be dragged past each other, so order the
        // pair rather than trusting which is which.
        let bounds = [lowerBound, upperBound].sorted()
        config.layer.paint.sample.drawRange = Self.celsius(bounds[0])...Self.celsius(bounds[1])

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .temperatures
            )
            try mapController.addWeatherLayer(config: config, beforeId: beforeId)
        } catch {
            print("Failed to add the temperatures layer: \(error)")
        }
    }

    private static func celsius(_ fahrenheit: Double) -> Double {
        (fahrenheit - 32) * 5.0 / 9.0
    }
}

#Preview {
    AdjustDrawRangeExample()
}
