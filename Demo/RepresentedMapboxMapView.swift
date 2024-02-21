//
//  RepresentedMapboxView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/12/24.
//

import SwiftUI
import Combine
import OSLog
import MapboxMaps
import MapsGLMaps
import MapsGLMapbox



/// Manages the ``MapboxMaps.MapView`` instance and presents it in SwiftUI, and uses a MapsGL ``MapboxMapController`` to add & remove the weather layers to the ``MapView`` in response to SwiftUI/Combine change updates of the Demo's ``WeatherLayersModel``.
struct RepresentedMapboxMapView : UIViewRepresentable
{
	private let _logger = Logger(type: Self.self)
	
	var mapInitOptions = MapboxMaps.MapInitOptions()
	
	@ObservedObject var dataModel: WeatherLayersModel
	
	
	class Coordinator
	{
		/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the ``MapboxMaps.MapView``.
		var mapController: MapboxMapController!
		
		/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
		/// Used for change-checking in comparison to the ``dataModel.selectedLayerCodes`` to determine if there are new layers that need to be added, or old layers that need to be removed.
		var activeLayerCodes: Set<WeatherService.LayerCode> = []
		
		/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
		var eventSubscriptions: Set<AnyCancellable> = []
	}
	
	func makeCoordinator() -> Coordinator { Coordinator() }
	
	
	func makeUIView(context: Self.Context) -> MapboxMaps.MapView
	{
		// Set up the ``MapboxMaps.MapView``.
		MapboxOptions.accessToken = AccessKeys.shared.mapboxAccessToken
		let mapView = MapboxMaps.MapView(
			frame: .zero,
			mapInitOptions: self.mapInitOptions
		)
		try! mapView.mapboxMap.setProjection(.init(name: .mercator)) // Set 2D map projection
		
		let maximumFPS = Float(UIScreen.main.maximumFramesPerSecond)
		mapView.preferredFrameRateRange = .init(minimum: maximumFPS * 2 / 3, maximum: maximumFPS, preferred: maximumFPS)
		
		// Set up the MapsGL ``MapboxMapController``, which will handling adding/removing MapsGL weather layers to the ``MapboxMaps.MapView``.
		let mapController = MapboxMapController(
			map: mapView,
			account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
		)
		context.coordinator.mapController = mapController
		
		// Once the map has completed initial load…
		mapController.subscribe(to: MapEvents.Load.self) { _ in
			// Start listening to Combine-provided change events of the `dataModel`'s selected layers.
			self.dataModel.$selectedLayerCodes.sink { selectedLayerCodes in
				// Remove any layers that are no longer selected.
				let layerCodesToRemove = context.coordinator.activeLayerCodes.subtracting(selectedLayerCodes)
				if !layerCodesToRemove.isEmpty {
					_logger.debug("Removing layers: \(layerCodesToRemove)")
					for code in layerCodesToRemove {
						mapController.removeWeatherLayer(forCode: code)
					}
				}
				
				// Construct the configuration for and add any layers that are newly selected.
				let layerCodesToAdd = selectedLayerCodes.subtracting(context.coordinator.activeLayerCodes)
				if !layerCodesToAdd.isEmpty {
					_logger.debug("Adding layers: \(layerCodesToAdd)")
					for code in layerCodesToAdd {
						do {
							let layer = WeatherLayersModel.allLayersByCode[code]!
							try mapController.addWeatherLayer(config: layer.makeConfiguration(mapController.service))
						} catch {
							_logger.error("Failed to add weather layer: \(error)")
						}
					}
				}
				
				context.coordinator.activeLayerCodes = selectedLayerCodes
			}
			.store(in: &context.coordinator.eventSubscriptions)
		}
		.store(in: &context.coordinator.eventSubscriptions)
		
		return mapView
	}
	
	func updateUIView(_ uiView: MapboxMaps.MapView, context: Context) {}
}



#Preview {
	RepresentedMapboxMapView(
		mapInitOptions: .init(
			cameraOptions: .init(center: .geographicCenterOfContiguousUSA, zoom: 2),
			styleURI: .light
		),
		dataModel: WeatherLayersModel(selectedLayerCodes: [ .temperatures ])
	)
}
