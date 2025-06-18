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


struct ContentView : View {
	private let _logger = Logger(type: Self.self)
	
	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
    
    @State private var timelinePosition: Double = 0
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State private var endDate = Date()
    @State private var currentDate = Date()
    @State private var speedFactor: Double = 1.0
    @State private var isPlaying: Bool = false
    @State private var isLoading: Bool = false
	
	private static let locationFinder = LocationFinder()
	@State private var locationFinderAlertIsPresented: Bool = false
	@State private var locationFinderError: LocationFinder.Error? = nil {
		didSet {
			if self.locationFinderError != nil {
				self.locationFinderAlertIsPresented = true
			}
		}
	}
    
    // detect iPad vs iPhone (or regular vs compact width)
    @Environment(\.horizontalSizeClass) private var hSizeClass
	
	class Coordinator {
		/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the `MapboxMaps.MapView`.
		var mapController: MapboxMapController!
		
		/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
		/// Used for change-checking in comparison to the ``RepresentedMapboxMapView/dataModel``.``WeatherLayersModel/selectedLayerCodes`` to determine if there are new layers that need to be added, or old layers that need to be removed.
		var activeLayerCodes: Set<WeatherService.LayerCode> = []
		
		/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
		var eventSubscriptions: Set<AnyCancellable> = []
		
		/// Mapbox's camera manager, used to trigger `fly(to:…)` animations.
		var camera: MapboxMaps.CameraAnimationsManager?
		
		let colorScheme: ColorScheme = (UITraitCollection.current.userInterfaceStyle == .dark) ? .dark : .light
	}
	private let coordinator = Coordinator()
    
    @ViewBuilder
    private var mapContent: some View {
        ZStack {
            MapReader { proxy in
                Map(initialViewport: .camera(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))
                    .mapStyle((coordinator.colorScheme == .dark) ? .dark : .light)
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
            .ignoresSafeArea()

            layersButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 30)

            currentLocationButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 30)

            SidebarView(dataModel: dataModel,
                        isSidebarVisible: $isSidebarVisible)
        }
        .environment(\.colorScheme, coordinator.colorScheme)
    }
	
	var body: some View {
        let startDateBinding = Binding<Date>(
            get: { startDate },
            set: { newValue in
                startDate = newValue
                coordinator.mapController.timeline.startDate = newValue
            }
        )
        let endDateBinding = Binding<Date>(
            get: { endDate },
            set: { newValue in
                endDate = newValue
                coordinator.mapController.timeline.endDate = newValue
            }
        )
        let speedFactorBinding = Binding<Double>(
            get: { speedFactor },
            set: { newValue in
                speedFactor = newValue
                coordinator.mapController.timeline.timeScale = newValue
            }
        )
        let sliderBinding = Binding<Double>(
            get: { timelinePosition },
            set: { newValue in
                timelinePosition = newValue
                coordinator.mapController.timeline.goTo(position: newValue)
                print("Scrubbed to: \(newValue)")
            }
        )
        let isPlayingBinding = Binding<Bool>(
            get: { isPlaying },
            set: { newValue in
                isPlaying = newValue
                
                let timeline = coordinator.mapController.timeline
                if isPlaying {
                    timeline.play()
                } else {
                    timeline.stop()
                }
            }
        )
        
        let timeline = TimelineView(
            timelinePosition: sliderBinding,
            startDate: startDateBinding,
            endDate: endDateBinding,
            currentDate: $currentDate,
            selectedSpeed: speedFactorBinding,
            isPlaying: isPlayingBinding,
            isLoading: $isLoading
        )
        
		ZStack {
            if hSizeClass == .regular {
                // iPad
                ZStack {
                    mapContent
                    timeline
                        .frame(maxWidth: 360)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .background(Color.backgroundColor)
                        .environment(\.colorScheme, .dark)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding([.bottom, .trailing], 16)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .bottomTrailing)     // pin to bottom-right
                        .zIndex(1)
                }
            } else {
                // iPhone
                VStack(spacing: 0) {
                    mapContent
                    timeline
                        .padding(.bottom, 0)
                        .background(Color.backgroundColor)
                        .environment(\.colorScheme, .dark)
                }
            }
            
            SidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
        }
        .environment(\.colorScheme, coordinator.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            $startDate.wrappedValue = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            $endDate.wrappedValue = Date()
            $currentDate.wrappedValue = Date()
        }
	}
	
	private func setUpMap(map: MapboxMap, camera: CameraAnimationsManager?) {
			coordinator.camera = camera
			
			try! map.setProjection(.init(name: .mercator)) // Set 2D map projection
			
			// Set up the MapsGL ``MapboxMapController``, which will handling adding/removing MapsGL weather layers to the ``MapboxMaps.MapView``.
			let mapController = MapboxMapController(
				map: map,
				window: UIWindow?.none,
				account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
			)
			coordinator.mapController = mapController
        
            // Set up event observers for when MapsGL data is loading
            mapController.onLoadStart.observe {
                $isLoading.wrappedValue = true
            }.store(in: &coordinator.eventSubscriptions)
            
            mapController.onLoadComplete.observe {
                $isLoading.wrappedValue = false
            }.store(in: &coordinator.eventSubscriptions)
        
            // Set up timeline range and event observers
            let timeline = mapController.timeline
            timeline.startDate = $startDate.wrappedValue
            timeline.endDate = $endDate.wrappedValue
            $currentDate.wrappedValue = timeline.currentDate
            $timelinePosition.wrappedValue = timeline.position
        
            timeline.onAdvance.publisher.receive(on: DispatchQueue.main).sink { progress in
                $timelinePosition.wrappedValue = timeline.position
                $currentDate.wrappedValue = timeline.currentDate
            }.store(in: &coordinator.eventSubscriptions)
			
			// Once the map has completed initial load…
            mapController.onLoad.observe { _ in
                WeatherLayersModel.store.loadMetadata(service: coordinator.mapController.service)
				// Start listening to Combine-provided change events of the `dataModel`'s selected layers.
				self.dataModel.$selectedLayerCodes.sink { selectedLayerCodes in
					// Remove any layers that are no longer selected.
					let layerCodesToRemove = coordinator.activeLayerCodes.subtracting(selectedLayerCodes)
					if !layerCodesToRemove.isEmpty {
						_logger.debug("Removing layers: \(layerCodesToRemove)")
						for code in layerCodesToRemove {
							mapController.removeWeatherLayer(for: code)
						}
					}
					
					// Construct the configuration for and add any layers that are newly selected.
					let layerCodesToAdd = selectedLayerCodes.subtracting(coordinator.activeLayerCodes)
					if !layerCodesToAdd.isEmpty {
						_logger.debug("Adding layers: \(layerCodesToAdd)")
						
						let roadLayerId = mapController.map.firstLayer(matching: /^(?:tunnel|road|bridge)-/)?.id
						for code in layerCodesToAdd {
							do {
                                if let layer = WeatherLayersModel.store.allLayersByCode()[code] {
                                    try mapController.addWeatherLayer(for: layer.code, beforeId: roadLayerId)
                                }
							} catch {
								_logger.error("Failed to add weather layer: \(error)")
							}
						}
					}
					
					coordinator.activeLayerCodes = selectedLayerCodes
				}
				.store(in: &coordinator.eventSubscriptions)
			}.store(in: &coordinator.eventSubscriptions)
	}
	
	var layersButton: some View {
        CircularIconButton(imageName: "MapsGL.Stack", action: {
            self.isSidebarVisible.toggle()
        })
        .shadow(color: .shadowColor, radius: 8, y: +2)
        .padding(.all, 12)
	}
	
	var currentLocationButton: some View {
        CircularIconButton(imageName: "MapsGL.Location", action: {
            Self.locationFinder.findCurrentLocation { location in
                coordinator.camera?.fly(to: .init(center: location.coordinate, zoom: currentLocationZoom))
            } failure: { error in
                self.locationFinderError = error
            }
        })
        .shadow(color: .shadowColor, radius: 8, y: +2)
        .padding(.all, 12)
	}
}

#Preview {
	ContentView(
		dataModel: WeatherLayersModel()
	)
}
