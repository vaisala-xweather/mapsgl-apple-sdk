//
//  ChangeMapUnitsExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Switching the units every layer, legend and readout displays.
///
/// `MapController.units` is the single source of truth: `setUnits(_:)` changes it and
/// notifies everything that displays a value through `onUnitsChange`. Layers keep
/// their data in metric regardless — only the presentation changes, so nothing
/// reloads.
///
/// ``MeasurementUnits`` is a set of per-quantity units rather than one flag, so a
/// single quantity can be changed on its own: here only `speed` moves, and the
/// temperature, distance and pressure units stay as they were.
struct ChangeMapUnitsExample: View {
    private enum Speed: String, CaseIterable, Identifiable {
        case kilometersPerHour = "km/h"
        case milesPerHour = "mph"
        case metersPerSecond = "m/s"

        var id: Self { self }

        var unit: UnitSpeed {
            switch self {
            case .kilometersPerHour: .kilometersPerHour
            case .milesPerHour: .milesPerHour
            case .metersPerSecond: .metersPerSecond
            }
        }
    }

    @State private var speed: Speed = .milesPerHour
    @State private var unitsDescription = ""

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -93), zoom: 4) { mapController, subscriptions in
            // The fill shows the field; the text layer prints values at city points,
            // which is what makes a units change visible on the map itself.
            for code in [WeatherService.LayerCode.windSpeeds, .windSpeedsText] {
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

            // The value labels compete with the basemap's own place names.
            DemoMapProvider.setPlaceLabelLayersVisible(false, for: mapController)

            apply(speed, to: mapController)

            // Anything showing a value should follow this rather than track its own copy.
            mapController.onUnitsChange.observe { units in
                unitsDescription = Self.describe(units)
            }.store(in: &subscriptions)
        } overlay: { mapController in
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                // The legend restyles itself for the active units too.
                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()

                VStack(alignment: .leading, spacing: 14) {
                    ExampleControlGroup(title: "Wind speed units") {
                        Picker("Units", selection: $speed) {
                            ForEach(Speed.allCases) { speed in
                                Text(speed.rawValue).tag(speed)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: speed) { newValue in
                            guard let mapController else { return }
                            apply(newValue, to: mapController)
                        }
                    }

                    Text(unitsDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .exampleControlSurface()
            }
        }
    }

    /// Changes one quantity, leaving the rest of the set alone.
    private func apply(_ speed: Speed, to mapController: DemoMapController) {
        var units = mapController.units
        units.speed = speed.unit
        mapController.setUnits(units)
        unitsDescription = Self.describe(mapController.units)
    }

    private static func describe(_ units: MeasurementUnits) -> String {
        "Speed \(units.speed.symbol) · Temperature \(units.temperature.symbol) · Distance \(units.distance.symbol)"
    }
}

#Preview {
    ChangeMapUnitsExample()
}
