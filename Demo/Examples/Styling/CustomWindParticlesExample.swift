//
//  CustomWindParticlesExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Tuning the wind particle field: how many, how fast, how they trail.
///
/// A particle layer's paint carries both a ``SamplePaint`` — the color scale mapping
/// wind speed to particle color — and a ``ParticlePaint`` controlling the simulation.
/// `density` trades visual richness against rendering cost, so it's the knob to reach
/// for on lower-end devices; `speed` scales motion without changing the data;
/// `trailsFade` sets how long a particle's tail persists.
///
/// The color scale here is `normalized`, so its stops run `0...1` across whatever
/// range the data covers rather than naming wind speeds outright.
struct CustomWindParticlesExample: View {
    @State private var density: ParticleDensity = .extreme
    @State private var speed: Double = 2.0

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47.60621, longitude: 10.33207), zoom: 3) { mapController, subscriptions in
            addParticles(to: mapController)
        } overlay: { mapController in
            ExampleControlPanel {
                ExampleControlGroup(title: "Density") {
                    Picker("Density", selection: $density) {
                        Text("Low").tag(ParticleDensity.low)
                        Text("Normal").tag(ParticleDensity.normal)
                        Text("High").tag(ParticleDensity.high)
                        Text("Extreme").tag(ParticleDensity.extreme)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: density) { _ in reload(mapController) }
                }

                ExampleControlGroup(title: "Speed") {
                    HStack(spacing: 12) {
                        Slider(value: $speed, in: 0.25...3.0) { isEditing in
                            guard isEditing == false else { return }
                            reload(mapController)
                        }
                        Text(String(format: "%.2gx", speed))
                            .font(.caption.monospacedDigit())
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func reload(_ mapController: DemoMapController?) {
        guard let mapController else { return }
        mapController.removeWeatherLayer(for: .windParticles)
        addParticles(to: mapController)
    }

    private func addParticles(to mapController: DemoMapController) {
        var config = WeatherService.WindParticles(service: mapController.service)

        config.layer.paint.particle.density = density
        config.layer.paint.particle.size = CGSize(width: 1, height: 1)
        config.layer.paint.particle.speed = speed
        config.layer.paint.particle.trails = true
        config.layer.paint.particle.trailsFade = 0.9

        config.layer.paint.sample.colorScale = .colorScale(
            ColorScaleOptions(
                stops: [
                    ColorStop(0, .fromString("#0b0089")),
                    ColorStop(0.25, .fromString("#8800a8")),
                    ColorStop(0.5, .fromString("#cf4875")),
                    ColorStop(0.75, .fromString("#f99336")),
                    ColorStop(1, .fromString("#f0fb00"))
                ],
                normalized: true
            )
        )

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .windParticles
            )
            try mapController.addWeatherLayer(config: config, beforeId: beforeId)
        } catch {
            print("Failed to add the wind particles layer: \(error)")
        }
    }
}

#Preview {
    CustomWindParticlesExample()
}
