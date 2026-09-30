//
//  DemoMapProvider.swift
//  Demo
//

import SwiftUI
import MapsGLMaps
import CoreLocation
import UIKit

import MapsGLMapbox
import MapboxMaps
public typealias DemoMapController = MapboxMapController
public typealias DemoUIKitMapView = MapboxMaps.MapView

private let defaultLightStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json")!
private let defaultDarkStyleURL = URL(string: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json")!

#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
private var maximumFPS: Float { Float(UIScreen.main.maximumFramesPerSecond) }
#endif

enum DemoMapProvider {
    static func configureSDK() {
        MapboxOptions.accessToken = AccessKeys.shared.mapboxAccessToken
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
        let options = MapInitOptions(
            cameraOptions: CameraOptions(
                center: initialCenter,
                zoom: initialZoom
            ),
            styleURI: .streets
        )

        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: options)
        mapView.mapboxMap.styleURI = (traitCollection.userInterfaceStyle == .dark) ? .dark : .light
        try! mapView.mapboxMap.setProjection(.init(name: .mercator)) // swiftlint:disable:this force_try
        mapView.mapboxMap.setCamera(to: .init(center: initialCenter, zoom: initialZoom))

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        mapView.preferredFrameRateRange = .init(minimum: maximumFPS * 2 / 3, maximum: maximumFPS, preferred: maximumFPS)
        #endif

        return mapView
    }

    static func fly(mapView: DemoUIKitMapView, to coordinate: CLLocationCoordinate2D, zoom: Double) {
        mapView.camera.fly(to: .init(center: coordinate, zoom: zoom))
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
        let map = mapController.map
        for layer in map.allLayerIdentifiers where layer.type == .symbol {
            let textField = map.layerProperty(for: layer.id, property: "text-field").value
            guard !(textField is NSNull) else {
                continue
            }

            try? map.setLayerProperty(for: layer.id, property: "visibility", value: visible ? "visible" : "none")
        }
    }

    static func defaultWeatherLayerInsertBeforeId(for mapController: DemoMapController) -> String? {
        return mapController.map.allLayerIdentifiers.first { layer in
            guard layer.type == .symbol else {
                return false
            }

            let textField = mapController.map.layerProperty(for: layer.id, property: "text-field").value
            return !(textField is NSNull)
        }?.id
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
        MapReader { proxy in
            Map(initialViewport: .camera(center: initialCenter, zoom: initialZoom))
                .mapStyle((colorScheme == .dark) ? .dark : .light)
                .ornamentOptions(OrnamentOptions(
                    scaleBar: ScaleBarViewOptions(
                        margins: CGPoint(x: Self.ornamentEdgeInset, y: Self.ornamentEdgeInset + ornamentInsets.top)
                    ),
                    logo: LogoViewOptions(
                        margins: CGPoint(x: Self.ornamentEdgeInset, y: Self.ornamentEdgeInset + ornamentInsets.bottom)
                    ),
                    attributionButton: AttributionButtonOptions(
                        margins: CGPoint(x: Self.ornamentEdgeInset, y: Self.ornamentEdgeInset + ornamentInsets.bottom)
                    )
                ))
                #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
                .frameRate(range: (maximumFPS * 2 / 3)...maximumFPS, preferred: maximumFPS)
                #endif
                .onAppear {
                    guard !session.didCreateController, let map = proxy.map else { return }
                    session.didCreateController = true

                    try? map.setProjection(.init(name: .mercator))
                    let mapController = MapboxMapController(
                        map: map,
                        window: UIWindow?.none,
                        account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
                    )
                    onMapReady(mapController) { coordinate, zoom in
                        proxy.camera?.fly(to: .init(center: coordinate, zoom: zoom))
                    }
                }
        }
    }
}

