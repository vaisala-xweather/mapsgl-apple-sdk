//
//  CustomRadarColorsExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Recoloring radar, which carries three precipitation types in one tile.
///
/// Radar's paint is a ``ColorScaleSpecification/masks(_:)`` rather than a single
/// scale: each precipitation type lives in its own color band of the encoded tile —
/// red is rain, green is snow, blue is wintry mix — and each gets its own scale over
/// the shared `0...87` dBZ range. Replace one band's stops and only that
/// precipitation type changes.
///
/// Stops are in dBZ, the unit of the underlying data, not display units.
///
/// The generic palettes take the other route: one scale over reflectivity alone,
/// with `normalized` stops running `0...1` instead of naming dBZ values. That drops
/// the precipitation-type distinction entirely, and switches the layer's renderer
/// from the multiband path to the single-scale one. The legend redraws from
/// whichever scale is in effect.
struct CustomRadarColorsExample: View {
    private enum Palette: String, CaseIterable, Identifiable {
        /// The masks the weather spec supplies, one scale per precipitation type.
        case `default` = "Default"
        /// Masks again, but with stops of our own.
        case custom = "Custom"
        // Generic sequential palettes, applied to reflectivity alone.
        case viridis = "Viridis"
        case inferno = "Inferno"
        case plasma = "Plasma"
        case magma = "Magma"
        case cividis = "Cividis"
        case mako = "Mako"

        var id: Self { self }

        /// The palette's colors, or `nil` for the two mask-based entries.
        var colors: [String]? {
            switch self {
            case .default, .custom:
                nil
            case .viridis:
                ["#440154", "#482777", "#3f4a8a", "#31678e", "#26838f", "#1f9d8a", "#6cce5a", "#b6de2b", "#fee825"]
            case .inferno:
                ["#000004", "#160b39", "#420a68", "#6a176e", "#932667", "#ba3655", "#ec6149", "#f0882c", "#f6a625"]
            case .plasma:
                ["#0d0887", "#46039f", "#7201a8", "#9c179e", "#bd3786", "#d8576b", "#ed7953", "#fb9f3a", "#fdca26"]
            case .magma:
                ["#000004", "#1b0c41", "#4a0c6b", "#781c6d", "#a52c60", "#cf4446", "#f1642e", "#fca636", "#f0f921"]
            case .cividis:
                ["#002350", "#193B6E", "#50566C", "#787877", "#A29A76", "#D6C363", "#FFE945"]
            case .mako:
                ["#12070B", "#352446", "#414283", "#3579A3", "#36A6AC", "#79D5AF", "#DBF4E3"]
            }
        }
    }

    @State private var palette: Palette = .custom

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -93), zoom: 4) { mapController, subscriptions in
            addRadar(to: mapController, palette: palette)
        } overlay: { mapController in
            VStack(alignment: .trailing, spacing: 8) {
                Spacer()

                LegendControlView(mapControllerProvider: { mapController })
                    .exampleLegendFrame()

                VStack(alignment: .leading, spacing: 14) {
                    ExampleControlGroup(title: "Color scale") {
                        Picker("Color scale", selection: $palette) {
                            ForEach(Palette.allCases) { palette in
                                Text(palette.rawValue).tag(palette)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: palette) { newValue in
                            guard let mapController else { return }
                            mapController.removeWeatherLayer(for: .radar)
                            addRadar(to: mapController, palette: newValue)
                        }
                    }
                }
                .exampleControlSurface()
            }
        }
    }

    private func addRadar(to mapController: DemoMapController, palette: Palette) {
        var config = WeatherService.Radar(service: mapController.service)

        switch palette {
        case .default:
            // Leaves the built-in masks the weather spec supplies in place.
            break
        case .custom:
            config.layer.paint.sample.colorScale = .masks(Self.customMasks)
        default:
            // One scale rather than masks, which also swaps the layer's renderer from
            // the multiband path to the single-scale one: reflectivity is colored on
            // its own and precipitation type stops being distinguished.
            config.layer.paint.sample.colorScale = .colorScale(
                Self.normalizedScale(palette.colors ?? [])
            )
        }

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .radar
            )
            try mapController.addWeatherLayer(config: config, beforeId: beforeId)
        } catch {
            print("Failed to add the radar layer: \(error)")
        }
    }

    /// Spreads `colors` evenly over a normalized `0...1` scale, behind a transparent
    /// first stop.
    ///
    /// `normalized` means the stops describe positions across whatever range the data
    /// covers rather than dBZ values, so one palette suits any layer. The transparent
    /// stop matters: without it the scale's first color fills the entire map wherever
    /// reflectivity is zero.
    private static func normalizedScale(_ colors: [String]) -> ColorScaleOptions {
        let all = ["rgba(0,0,0,0)"] + colors
        let step = 1.0 / Double(all.count - 1)

        return ColorScaleOptions(
            stops: all.enumerated().map { index, color in
                ColorStop(Double(index) * step, .fromString(color))
            },
            normalized: true
        )
    }

    /// One scale per precipitation band. The band a scale is assigned to is what makes
    /// it rain, snow or mix — not its position in this array.
    private static let customMasks: [ColorMaskOptions] = [
        .init(
            band: .red, // rain
            colorScale: .init(
                stops: [
                    ColorStop(0, .fromString("rgba(0,0,0,0)")),
                    ColorStop(5.9, .fromString("rgba(113,255,194,0)")),
                    ColorStop(6, .fromString("#588d45")),
                    ColorStop(40, .fromString("#a1943a")),
                    ColorStop(70, .fromString("#fa0000"))
                ],
                range: 0.0...87.0
            )
        ),
        .init(
            band: .green, // snow
            colorScale: .init(
                stops: [
                    ColorStop(0, .fromString("rgba(0,0,0,0)")),
                    ColorStop(5.9, .fromString("rgba(248,178,205,0)")),
                    ColorStop(6, .fromString("#E9AAC0")),
                    ColorStop(25, .fromString("#E93D7A")),
                    ColorStop(58, .fromString("#DB1E16")),
                    ColorStop(87, .fromString("#58003c"))
                ],
                range: 0.0...87.0
            )
        ),
        .init(
            band: .blue, // wintry mix
            colorScale: .init(
                stops: [
                    ColorStop(0, .fromString("rgba(0,0,0,0)")),
                    ColorStop(5.9, .fromString("rgba(255,255,255,0)")),
                    ColorStop(25, .fromString("#9B9BE5")),
                    ColorStop(45, .fromString("#0000af")),
                    ColorStop(58, .fromString("#535DFF")),
                    ColorStop(87, .fromString("#373EA8"))
                ],
                range: 0.0...87.0
            )
        )
    ]
}

#Preview {
    CustomRadarColorsExample()
}
