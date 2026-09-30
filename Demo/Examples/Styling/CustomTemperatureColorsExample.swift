//
//  CustomTemperatureColorsExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Replacing a sample layer's color scale, and choosing between a gradient and bands.
///
/// A sample layer colorizes continuous data through
/// ``ColorScaleSpecification/colorScale(_:)``. `interval` decides the character of the
/// result: `0` interpolates smoothly between stops, while a non-zero value quantizes
/// the scale into steps of that size — useful when readers need to judge a value
/// rather than a trend.
///
/// Stops and intervals are in Celsius. All MapsGL data values are metric regardless
/// of the units the map displays, so a 2°F step is expressed as the Celsius interval
/// of the same size.
struct CustomTemperatureColorsExample: View {
    private enum Banding: String, CaseIterable, Identifiable {
        case gradient = "Gradient"
        case twoFahrenheit = "2°F bands"
        case fiveCelsius = "5°C bands"

        var id: Self { self }

        /// In Celsius, the unit of the data.
        var interval: Double {
            switch self {
            case .gradient: 0
            case .twoFahrenheit: 2 * 5.0 / 9.0
            case .fiveCelsius: 5
            }
        }
    }

    @State private var banding: Banding = .twoFahrenheit

    private static let stops: [ColorStop] = [
        ColorStop(-60, .fromString("#FFFFFF")),
        ColorStop(-50, .fromString("#9C619B")),
        ColorStop(-40, .fromString("#58005b")),
        ColorStop(-30, .fromString("#ce00d7")),
        ColorStop(-20, .fromString("#121475")),
        ColorStop(-10, .fromString("#5b97f8")),
        ColorStop(0, .fromString("#81e8ff")),
        ColorStop(5, .fromString("#0f7001")),
        ColorStop(15, .fromString("#ecf93d")),
        ColorStop(25, .fromString("#e90f0b")),
        ColorStop(35, .fromString("#6b0001")),
        ColorStop(45, .fromString("#fff7e2")),
        ColorStop(50, .fromString("#7b7b7b"))
    ]

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47.60621, longitude: -122.33207), zoom: 4) { mapController, subscriptions in
            addTemperatures(to: mapController, interval: banding.interval)
        } overlay: { mapController in
            ExampleControlPanel {
                ExampleControlGroup(title: "Color scale") {
                    Picker("Color scale", selection: $banding) {
                        ForEach(Banding.allCases) { banding in
                            Text(banding.rawValue).tag(banding)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: banding) { newValue in
                        guard let mapController else { return }
                        mapController.removeWeatherLayer(for: .temperatures)
                        addTemperatures(to: mapController, interval: newValue.interval)
                    }
                }
            }
        }
    }

    private func addTemperatures(to mapController: DemoMapController, interval: Double) {
        var config = WeatherService.Temperatures(service: mapController.service)
        config.layer.paint.sample.colorScale = .colorScale(
            ColorScaleOptions(stops: Self.stops, interval: interval)
        )

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
}

#Preview {
    CustomTemperatureColorsExample()
}
