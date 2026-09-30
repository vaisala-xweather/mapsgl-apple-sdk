//
//  DisplayAWeatherMapExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// The smallest useful MapsGL integration, written out in full.
///
/// Every other SwiftUI example is built on ``ExampleMapView``, which owns the map,
/// the controller and the Combine subscriptions so that an example file contains
/// only the API it is demonstrating. This one does that work itself, so there is
/// one place to read what the scaffold does on the others' behalf.
/// ``UIKitIntegrationExample`` is the same integration without SwiftUI.
///
/// Three things an integration has to get right are visible here:
///
/// - **Something has to own the controller and the subscriptions.** SwiftUI
///   re-evaluates `body` freely; the controller must survive that. A `StateObject`
///   does, which is why the wiring lives in ``WeatherMapModel`` and not in `body`.
/// - **Weather layers are added after `onLoad`.** The controller exists as soon as
///   the map view does, but the map's style does not, and a layer added against a
///   style that has not loaded yet is dropped.
/// - **The map-ready callback can run more than once** for the same map, so
///   attaching guards against wiring it twice.
/// - **The controller has to be let go of.** It owns the map, so the model detaches
///   it when the screen goes away, and its observers hold it weakly.
///
/// `addWeatherLayer(for:beforeId:)` builds the layer's source, paint, legend and
/// inspector formatting from the weather spec, so one call per layer is enough.
/// Layers stack in the order they are added — radar first, then alert outlines over
/// it — and `beforeId` keeps the base map's place labels above both.
struct DisplayAWeatherMapExample: View {
    @StateObject private var model = WeatherMapModel()

    /// Follows the system appearance, so the basemap restyles when it changes.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        DemoSwiftUIMapView(
            colorScheme: colorScheme,
            initialCenter: CLLocationCoordinate2D(latitude: 40, longitude: -85.5),
            initialZoom: 3,
            // The mapping library's own ornaments move rather than the demo's
            // chrome: the scale bar drops below the floating back button, and the
            // logo and attribution lift far enough off the bottom edge to stay
            // legible in a documentation screenshot.
            ornamentInsets: .init(
                top: ExampleChrome.controlsTopInset,
                bottom: ExampleCaptureMode.hidesControls ? XWSpace.x4 : 0
            )
        ) { mapController, _ in
            model.attach(mapController)
        }
        .ignoresSafeArea()
    }
}

/// Owns the map controller and the Combine subscriptions for
/// ``DisplayAWeatherMapExample``.
///
/// Held as a `StateObject` so that both outlive any one evaluation of the view's
/// body. Releasing the bag cancels the observers, so its lifetime is the
/// observation's lifetime.
@MainActor
final class WeatherMapModel: ObservableObject {
    private var mapController: DemoMapController?
    private var subscriptions: Set<AnyCancellable> = []

    /// Takes the controller back off the map when this model is released.
    private var detacher: ExampleMapDetacher?

    /// Wires up a controller the map view has just handed over. Safe to call again
    /// for a map that is already attached.
    func attach(_ mapController: DemoMapController) {
        guard self.mapController == nil else {
            return
        }
        self.mapController = mapController
        self.detacher = ExampleMapDetacher(mapController)

        mapController.onLoad.observe { [weak self, weak mapController] _ in
            guard let self, let mapController else { return }
            self.addWeatherLayers(to: mapController)
        }.store(in: &subscriptions)
    }

    private func addWeatherLayers(to mapController: DemoMapController) {
        for code in [WeatherService.LayerCode.radar, .alertsOutline] {
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
    }
}

#Preview {
    DisplayAWeatherMapExample()
}
