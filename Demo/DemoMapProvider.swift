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

    static func makeUIKitMapView(traitCollection: UITraitCollection, initialZoom: Double) -> DemoUIKitMapView {
        let options = MapInitOptions(
            cameraOptions: CameraOptions(
                center: .geographicCenterOfContiguousUSA,
                zoom: initialZoom
            ),
            styleURI: .streets
        )

        let mapView = MapboxMaps.MapView(frame: .zero, mapInitOptions: options)
        mapView.mapboxMap.styleURI = (traitCollection.userInterfaceStyle == .dark) ? .dark : .light
        try! mapView.mapboxMap.setProjection(.init(name: .mercator)) // swiftlint:disable:this force_try
        mapView.mapboxMap.setCamera(to: .init(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))

        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
        mapView.preferredFrameRateRange = .init(minimum: maximumFPS * 2 / 3, maximum: maximumFPS, preferred: maximumFPS)
        #endif

        return mapView
    }

    static func fly(mapView: DemoUIKitMapView, to coordinate: CLLocationCoordinate2D, zoom: Double) {
        mapView.camera.fly(to: .init(center: coordinate, zoom: zoom))
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

struct DemoSwiftUIMapView: View {
    let colorScheme: ColorScheme
    let initialZoom: Double
    let onMapReady: (DemoMapController, @escaping (CLLocationCoordinate2D, Double) -> Void) -> Void

    var body: some View {
        MapReader { proxy in
            Map(initialViewport: .camera(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))
                .mapStyle((colorScheme == .dark) ? .dark : .light)
                #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
                .frameRate(range: (maximumFPS * 2 / 3)...maximumFPS, preferred: maximumFPS)
                #endif
                .onAppear {
                    guard let map = proxy.map else { return }
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

