//
//  UIKitIntegrationExample.swift
//  Demo
//

import Combine
import MapsGLMaps
import SwiftUI
import UIKit

/// Driving MapsGL from UIKit rather than SwiftUI.
///
/// The controller API is the same either way — the difference is only how the map
/// view is created and owned. Here a plain `UIViewController` builds the mapping
/// library's view, hands it to ``DemoMapProvider/makeMapController(for:)``, and adds
/// a weather layer once `onLoad` fires. ``ExampleMapView`` is deliberately not used,
/// so this file stands alone as a UIKit reference.
/// ``DisplayAWeatherMapExample`` is the same integration in SwiftUI.
///
/// The `UIViewControllerRepresentable` at the bottom exists only to host the
/// controller inside this SwiftUI demo app; a UIKit app pushes
/// ``WeatherMapViewController`` directly.
///
/// The view controller is the controller's only owner, so it detaches it — and with
/// it the map's tiles and GPU resources — when the screen is popped.
final class WeatherMapViewController: UIViewController {
    private var mapView: DemoUIKitMapView!
    private var mapController: DemoMapController?
    private var subscriptions: Set<AnyCancellable> = []

    /// Takes the controller back off the map when this view controller is released.
    private var detacher: ExampleMapDetacher?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView = DemoMapProvider.makeUIKitMapView(
            traitCollection: traitCollection,
            initialZoom: 3.5
        )
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)

        let mapController = DemoMapProvider.makeMapController(for: mapView)
        self.mapController = mapController
        self.detacher = ExampleMapDetacher(mapController)

        mapController.onLoad.observe { [weak self] _ in
            self?.addWeatherLayers()
        }.store(in: &subscriptions)
    }

    private func addWeatherLayers() {
        guard let mapController else {
            return
        }

        do {
            let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                for: mapController,
                layerCode: .temperatures
            )
            try mapController.addWeatherLayer(for: .temperatures, beforeId: beforeId)
        } catch {
            print("Failed to add the temperatures layer: \(error)")
        }
    }
}

struct UIKitIntegrationExample: View {
    var body: some View {
        WeatherMapViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

private struct WeatherMapViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WeatherMapViewController {
        WeatherMapViewController()
    }

    func updateUIViewController(_ uiViewController: WeatherMapViewController, context: Context) {}
}
