//
//  ContentView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import Combine
import OSLog
import MapboxMaps
import MapsGLMaps
import MapsGLMapbox



fileprivate let initialZoom: Double = 2.75
fileprivate let currentLocationZoom: Double = 4.0
#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
	fileprivate var maximumFPS: Float { Float(UIScreen.main.maximumFramesPerSecond) }
#endif // iOS, macCatalyst, tvOS



struct ContentView : View
{
	private let _logger = Logger(type: Self.self)
	
	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
	
	private static let locationFinder = LocationFinder()
	@State private var locationFinderAlertIsPresented: Bool = false
	@State private var locationFinderError: LocationFinder.Error? = nil {
		didSet {
			if self.locationFinderError != nil {
				self.locationFinderAlertIsPresented = true
			}
		}
	}
	
	
	class Coordinator
	{
		/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the `MapboxMaps.MapView`.
		var mapController: MapboxMapController!
		
		/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
		/// Used for change-checking in comparison to the ``RepresentedMapboxMapView/dataModel``.``WeatherLayersModel/selectedLayerCodes`` to determine if there are new layers that need to be added, or old layers that need to be removed.
		var activeLayerCodes: Set<WeatherService.LayerCode> = []
		
		/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
		var eventSubscriptions: Set<AnyCancellable> = []
		
		/// Mapbox's camera manager, used to trigger `fly(to:…)` animations.
		var camera: MapboxMaps.CameraAnimationsManager?
	}
	private let coordinator = Coordinator()
	
	
	var body: some View {
		ZStack {
			MapReader { proxy in
				Map(initialViewport: .camera(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))
					.mapStyle(.dark)
					#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
					.frameRate(range: (maximumFPS * 2 / 3)...maximumFPS, preferred: maximumFPS)
					#endif // iOS, macCatalyst, tvOS
					.ignoresSafeArea()
					.alert(isPresented: $locationFinderAlertIsPresented, error: self.locationFinderError) {
						Button("OK") {
							self.locationFinderError = nil
						}
					}
					.onAppear {
						guard let map = proxy.map else { return }
						setUpMap(map: map, camera: proxy.camera)
					}
			}
			
			Group { self.layersButton }
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
				.padding([ .top ], 30)
			
			Group { self.currentLocationButton }
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
				.padding([ .top ], 30)
				
			SidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
		}
	}
	
	private func setUpMap(map: MapboxMap, camera: CameraAnimationsManager?)
	{
			coordinator.camera = camera
			
			try! map.setProjection(.init(name: .mercator)) // Set 2D map projection
			
			// Set up the MapsGL ``MapboxMapController``, which will handling adding/removing MapsGL weather layers to the ``MapboxMaps.MapView``.
			let mapController = MapboxMapController(
				map: map,
				window: UIWindow?.none,
				account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
			)
			coordinator.mapController = mapController
			
			// Once the map has completed initial load…
			mapController.subscribe(to: MapEvents.Load.self) { _ in
				// Start listening to Combine-provided change events of the `dataModel`'s selected layers.
				self.dataModel.$selectedLayerCodes.sink { selectedLayerCodes in
					// Remove any layers that are no longer selected.
					let layerCodesToRemove = coordinator.activeLayerCodes.subtracting(selectedLayerCodes)
					if !layerCodesToRemove.isEmpty {
						_logger.debug("Removing layers: \(layerCodesToRemove)")
						for code in layerCodesToRemove {
							mapController.removeWeatherLayer(forCode: code)
						}
					}
					
					// Construct the configuration for and add any layers that are newly selected.
					let layerCodesToAdd = selectedLayerCodes.subtracting(coordinator.activeLayerCodes)
					if !layerCodesToAdd.isEmpty {
						_logger.debug("Adding layers: \(layerCodesToAdd)")
						
						let roadLayerId = mapController.map.firstLayer(matching: /^(?:tunnel|road|bridge)-/)?.id
						for code in layerCodesToAdd {
							do {
								let layer = WeatherLayersModel.allLayersByCode[code]!
								try mapController.addWeatherLayer(config: layer.makeConfiguration(mapController.service), beforeId: roadLayerId)
							} catch {
								_logger.error("Failed to add weather layer: \(error)")
							}
						}
					}
					
					coordinator.activeLayerCodes = selectedLayerCodes
				}
				.store(in: &coordinator.eventSubscriptions)
			}
			.store(in: &coordinator.eventSubscriptions)
	}
	
	var layersButton: some View {
		circleIconButton(imageName: "MapsGL.Stack")
			.onTapGesture {
				self.isSidebarVisible.toggle()
			}
	}
	
	var currentLocationButton: some View {
		circleIconButton(imageName: "MapsGL.Location")
			.onTapGesture {
				Self.locationFinder.findCurrentLocation { location in
					coordinator.camera?.fly(to: .init(center: location.coordinate, zoom: currentLocationZoom))
				} failure: { error in
					self.locationFinderError = error
				}
			}
	}
}



extension View
{
	func circleIconButton(imageName: String) -> some View {
		Circle()
			.fill(Color.backgroundColor)
			.frame(width: 44, height: 44)
			.shadow(color: .shadowColor, radius: 8, y: +2)
			.overlay {
				Image(imageName)
					.renderingMode(.template)
					.resizable().scaledToFit().frame(width: 24, height: 24)
					.foregroundColor(.textColor)
			}
			.padding(.all, 12)
	}
}



#Preview {
	ContentView(
		dataModel: WeatherLayersModel()
	)
}
