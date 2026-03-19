//
//  DemoMapProvider.swift
//  Demo
//

import SwiftUI
import MapsGLMaps
import CoreLocation
import UIKit

import MapsGLMapLibre
import MapLibre
public typealias DemoMapController = MapLibreMapController
public typealias DemoUIKitMapView = MLNMapView

private let defaultLightStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json")!
private let defaultDarkStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json")!

#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
private var maximumFPS: Float { Float(UIScreen.main.maximumFramesPerSecond) }
#endif

enum DemoMapProvider {
    static func configureSDK() {
    }

    static func makeMapController(for mapView: DemoUIKitMapView) -> DemoMapController {
        DemoMapController(
            map: mapView,
            account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
        )
    }

    static func makeUIKitMapView(traitCollection: UITraitCollection, initialZoom: Double) -> DemoUIKitMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.styleURL = (traitCollection.userInterfaceStyle == .dark) ? defaultDarkStyleURL : defaultLightStyleURL
        mapView.setCenter(.geographicCenterOfContiguousUSA, zoomLevel: initialZoom, animated: false)
        return mapView
    }

    static func fly(mapView: DemoUIKitMapView, to coordinate: CLLocationCoordinate2D, zoom: Double) {
        mapView.setCenter(coordinate, zoomLevel: zoom, animated: true)
    }

    static func defaultWeatherLayerInsertBeforeId(for mapController: DemoMapController) -> String? {
        return mapController.map.style?.layers.first(where: { $0 is MLNSymbolStyleLayer })?.identifier
    }
}

struct DemoSwiftUIMapView: View {
    let colorScheme: ColorScheme
    let initialZoom: Double
    let onMapReady: (DemoMapController, @escaping (CLLocationCoordinate2D, Double) -> Void) -> Void

    var body: some View {
        DemoMapLibreRepresentable(
            colorScheme: colorScheme,
            initialZoom: initialZoom,
            onMapReady: onMapReady
        )
    }
}

private struct DemoMapLibreRepresentable: UIViewRepresentable {
    let colorScheme: ColorScheme
    let initialZoom: Double
    let onMapReady: (DemoMapController, @escaping (CLLocationCoordinate2D, Double) -> Void) -> Void

    class Coordinator {
        var lastStyleURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        let styleURL = styleURL(for: colorScheme)
        context.coordinator.lastStyleURL = styleURL
        mapView.styleURL = styleURL
        mapView.setCenter(.geographicCenterOfContiguousUSA, zoomLevel: initialZoom, animated: false)

        let mapController = DemoMapProvider.makeMapController(for: mapView)
        onMapReady(mapController) { coordinate, zoom in
            mapView.setCenter(coordinate, zoomLevel: zoom, animated: true)
        }

        return mapView
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        let styleURL = styleURL(for: colorScheme)
        if context.coordinator.lastStyleURL != styleURL {
            context.coordinator.lastStyleURL = styleURL
            uiView.styleURL = styleURL
        }
    }

    private func styleURL(for colorScheme: ColorScheme) -> URL {
        switch colorScheme {
        case .dark:
            defaultDarkStyleURL
        default:
            defaultLightStyleURL
        }
    }
}
