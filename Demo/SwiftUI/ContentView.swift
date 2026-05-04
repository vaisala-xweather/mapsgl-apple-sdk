//
//  ContentView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import Combine
import OSLog
import MapsGLMaps
import CoreLocation

fileprivate let initialZoom: Double = 2.75
fileprivate let currentLocationZoom: Double = 4.0

struct ContentView : View {
	private let _logger = Logger(type: Self.self)

	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
    @State private var isLegendShown = false

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

	class Coordinator: ObservableObject {
		/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the `MapboxMaps.MapView`.
		var mapController: DemoMapController?
        
		/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
		var activeLayerCodes: Set<WeatherService.LayerCode> = []
        
		/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
		var eventSubscriptions: Set<AnyCancellable> = []
		var flyToLocation: ((CLLocationCoordinate2D, Double) -> Void)?

		let colorScheme: ColorScheme = (UITraitCollection.current.userInterfaceStyle == .dark) ? .dark : .light

		/// Preload source animation data while the animated timeline is paused.
		@Published var isPreloadEnabled: Bool = false {
			didSet {
				mapController?.animationOptions.shouldPreloadData = self.isPreloadEnabled
			}
		}
	}

	@StateObject
	private var coordinator = Coordinator()

    @ViewBuilder
    private var mapContent: some View {
        ZStack {
            DemoSwiftUIMapView(colorScheme: coordinator.colorScheme, initialZoom: initialZoom) { mapController, flyToLocation in
                if coordinator.mapController == nil {
                    coordinator.mapController = mapController
                    coordinator.flyToLocation = flyToLocation
                    bindMapController(mapController)
                }
            }
            .ignoresSafeArea()
            .alert(isPresented: $locationFinderAlertIsPresented, error: self.locationFinderError) {
                Button("OK") {
                    self.locationFinderError = nil
                }
            }
            .dataInspectorOverlay(mapControllerProvider: { coordinator.mapController })
            .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    layersButton
                        .padding(.top, 30)
                        .padding(.horizontal, 12)
                    legendButton
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                    Spacer()
                }
                Spacer()
                VStack(spacing: 0) {
                    currentLocationButton
                        .padding(.top, 30)
                        .padding(.horizontal, 12)
                    Spacer()
                }
            }

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
                coordinator.mapController?.timeline.startDate = newValue
            }
        )
        let endDateBinding = Binding<Date>(
            get: { endDate },
            set: { newValue in
                endDate = newValue
                coordinator.mapController?.timeline.endDate = newValue
            }
        )
        let speedFactorBinding = Binding<Double>(
            get: { speedFactor },
            set: { newValue in
                speedFactor = newValue
                coordinator.mapController?.timeline.timeScale = newValue
            }
        )
        let sliderBinding = Binding<Double>(
            get: { timelinePosition },
            set: { newValue in
                timelinePosition = newValue
                coordinator.mapController?.timeline.goTo(position: newValue)
            }
        )
        let isPlayingBinding = Binding<Bool>(
            get: { isPlaying },
            set: { newValue in
                isPlaying = newValue

                guard let timeline = coordinator.mapController?.timeline else { return }
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
            isLoading: $isLoading,
            isPreloadEnabled: $coordinator.isPreloadEnabled
        )

		ZStack {
            if hSizeClass == .regular {
                // iPad
                ZStack {
                    mapContent
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing) {
                            Spacer()
                            if isLegendShown {
                                LegendControlView(mapControllerProvider: { coordinator.mapController })
                                    .frame(maxWidth: 360)
                                    .padding([.bottom, .trailing], 24)
                            }
                            timeline
                                .frame(maxWidth: 360)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .background(Color.backgroundColor)
                                .environment(\.colorScheme, .dark)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                                .padding([.bottom, .trailing], 16)
                                .zIndex(1)
                        }
                    }
                }
            } else {
                // iPhone
                VStack(spacing: 0) {
                    ZStack {
                        mapContent
                        if isLegendShown {
                            HStack {
                                Spacer()
                                VStack {
                                    Spacer()
                                    LegendControlView(mapControllerProvider: { coordinator.mapController })
                                        .frame(maxWidth: 320)
                                        .padding(.horizontal)
                                        .padding(.bottom, 34)
                                }
                            }
                        }
                    }
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

    private func bindMapController(_ mapController: DemoMapController) {
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
        DispatchQueue.main.async {
            $currentDate.wrappedValue = timeline.currentDate
            $timelinePosition.wrappedValue = timeline.position
        }

        timeline.onAdvance.publisher.receive(on: DispatchQueue.main).sink { _ in
            $timelinePosition.wrappedValue = timeline.position
            $currentDate.wrappedValue = timeline.currentDate
        }.store(in: &coordinator.eventSubscriptions)

        // Once the map has completed initial load…
        
        mapController.onLoad.observe { _ in
            // Start listening to Combine-provided change events of the `dataModel`'s selected layers.
            WeatherLayersModel.store.loadMetadata(service: mapController.service)
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

                    let beforeLayerId = DemoMapProvider.defaultWeatherLayerInsertBeforeId(for: mapController)
                    for code in layerCodesToAdd {
                        do {
                            if let layer = WeatherLayersModel.store.allLayersByCode()[code] {
                                try mapController.addWeatherLayer(for: layer.code, beforeId: beforeLayerId)
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
	}

	var currentLocationButton: some View {
        CircularIconButton(imageName: "MapsGL.Location", action: {
            Self.locationFinder.findCurrentLocation { location in
                coordinator.flyToLocation?(location.coordinate, currentLocationZoom)
            } failure: { error in
                self.locationFinderError = error
            }
        })
        .shadow(color: .shadowColor, radius: 8, y: +2)
	}

    var legendButton: some View {
        CircularIconButton(systemName: "list.bullet.rectangle", action: {
            self.isLegendShown.toggle()
        })
        .shadow(color: .shadowColor, radius: 8, y: +2)
    }
}

#Preview {
	ContentView(
		dataModel: WeatherLayersModel()
	)
}
