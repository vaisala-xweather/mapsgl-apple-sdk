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

    static func makeUIKitMapView(
        traitCollection: UITraitCollection,
        initialCenter: CLLocationCoordinate2D = .geographicCenterOfContiguousUSA,
        initialZoom: Double
    ) -> DemoUIKitMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.styleURL = (traitCollection.userInterfaceStyle == .dark) ? defaultDarkStyleURL : defaultLightStyleURL
        mapView.setCenter(initialCenter, zoomLevel: initialZoom, animated: false)
        return mapView
    }

    static func fly(mapView: DemoUIKitMapView, to coordinate: CLLocationCoordinate2D, zoom: Double) {
        mapView.setCenter(coordinate, zoomLevel: zoom, animated: true)
    }

    /// Layer id that a weather layer for `layerCode` should be inserted below, or `nil` to insert it above every existing layer.
    ///
    /// Data-query text layers are inserted at the top of the stack so their values draw over the base style's own
    /// vector content (roads, boundaries, labels) rather than underneath it.
    static func weatherLayerInsertBeforeId(
        for mapController: DemoMapController,
        layerCode: WeatherService.LayerCode
    ) -> String? {
        layerCode.isDataQueryTextLayer ? nil : defaultWeatherLayerInsertBeforeId(for: mapController)
    }

    /// Shows or hides the base style's place-name/POI label layers, i.e. the symbol layers that carry a text field.
    static func setPlaceLabelLayersVisible(_ visible: Bool, for mapController: DemoMapController) {
        guard let style = mapController.map.style else {
            return
        }

        for case let layer as MLNSymbolStyleLayer in style.layers where layer.text != nil {
            layer.isVisible = visible
        }
    }

    static func defaultWeatherLayerInsertBeforeId(for mapController: DemoMapController) -> String? {
        guard let style = mapController.map.style else {
            return nil
        }

        let layers = style.layers
        let lastRoadLayerIndex = layers.lastIndex(where: { layer in
            guard layer is MLNLineStyleLayer else {
                return false
            }

            let identifier = layer.identifier.lowercased()
            return identifier.contains("road")
                || identifier.contains("bridge")
                || identifier.contains("tunnel")
        })

        if let lastRoadLayerIndex {
            return layers[(lastRoadLayerIndex + 1)...].first(where: {
                guard let layer = $0 as? MLNSymbolStyleLayer else {
                    return false
                }
                return layer.text != nil
            })?.identifier
        }

        return layers.first(where: {
            guard let layer = $0 as? MLNSymbolStyleLayer else {
                return false
            }
            return layer.text != nil
        })?.identifier
    }
}

/// Extra clearance for the mapping library's own scale bar, logo and attribution, so
/// the demo's floating chrome doesn't cover them.
///
/// Attribution has to stay legible — both Mapbox and MapLibre's data sources require
/// it — so the ornaments move rather than the controls.
struct DemoMapOrnamentInsets {
    var top: CGFloat = 0
    var bottom: CGFloat = 0

    static let zero = DemoMapOrnamentInsets()
}

/// One map's worth of setup, held across a ``DemoSwiftUIMapView``'s body
/// evaluations.
///
/// `onAppear` runs again every time the map comes back on screen, so this latch keeps
/// the controller to one per map.
private final class DemoMapSession: ObservableObject {
    var didCreateController = false
}

struct DemoSwiftUIMapView: View {
    /// Default distance of an ornament from the map's edge.
    private static let ornamentEdgeInset: CGFloat = 8

    @StateObject private var session = DemoMapSession()

    let colorScheme: ColorScheme
    let initialCenter: CLLocationCoordinate2D
    let initialZoom: Double
    let ornamentInsets: DemoMapOrnamentInsets
    let onMapReady: (DemoMapController, @escaping (CLLocationCoordinate2D, Double) -> Void) -> Void

    init(
        colorScheme: ColorScheme,
        initialCenter: CLLocationCoordinate2D = .geographicCenterOfContiguousUSA,
        initialZoom: Double,
        ornamentInsets: DemoMapOrnamentInsets = .zero,
        onMapReady: @escaping (DemoMapController, @escaping (CLLocationCoordinate2D, Double) -> Void) -> Void
    ) {
        self.colorScheme = colorScheme
        self.initialCenter = initialCenter
        self.initialZoom = initialZoom
        self.ornamentInsets = ornamentInsets
        self.onMapReady = onMapReady
    }

    var body: some View {
        DemoMapLibreRepresentable(
            colorScheme: colorScheme,
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            ornamentInsets: ornamentInsets,
            onMapReady: onMapReady
        )
    }
}

private struct DemoMapLibreRepresentable: UIViewRepresentable {
    private static let ornamentEdgeInset: CGFloat = 8

    let colorScheme: ColorScheme
    let initialCenter: CLLocationCoordinate2D
    let initialZoom: Double
    let ornamentInsets: DemoMapOrnamentInsets
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
        mapView.setCenter(initialCenter, zoomLevel: initialZoom, animated: false)

        applyOrnamentInsets(to: mapView)

        let mapController = DemoMapProvider.makeMapController(for: mapView)
        onMapReady(mapController) { coordinate, zoom in
            mapView.setCenter(coordinate, zoomLevel: zoom, animated: true)
        }

        return mapView
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        applyOrnamentInsets(to: uiView)

        let styleURL = styleURL(for: colorScheme)
        if context.coordinator.lastStyleURL != styleURL {
            context.coordinator.lastStyleURL = styleURL
            uiView.styleURL = styleURL
        }
    }

    private func applyOrnamentInsets(to mapView: MLNMapView) {
        let inset = Self.ornamentEdgeInset
        mapView.scaleBarMargins = CGPoint(x: inset, y: inset + ornamentInsets.top)
        mapView.logoViewMargins = CGPoint(x: inset, y: inset + ornamentInsets.bottom)
        mapView.attributionButtonMargins = CGPoint(x: inset, y: inset + ornamentInsets.bottom)
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
