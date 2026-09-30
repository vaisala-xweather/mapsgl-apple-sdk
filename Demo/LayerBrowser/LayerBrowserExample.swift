//
//  LayerBrowserExample.swift
//  Demo
//

import SwiftUI
import Combine
import OSLog
import MapsGLMaps
import CoreLocation

fileprivate let initialZoom: Double = 2.75
fileprivate let currentLocationZoom: Double = 4.0

/// Browse and toggle every weather layer the SDK exposes, with timeline playback,
/// the legend control, and the data inspector all wired up.
///
/// The other examples each demonstrate one API; this one is the kitchen sink, and
/// the closest thing to a working weather app in the demo.
struct LayerBrowserExample : View {
	@StateObject var dataModel = WeatherLayersModel(selectedLayerCodes: ExampleCaptureMode.layerCodes.map(Set.init) ?? [ .windParticles ])
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
    @State private var isLegendShown = false

    // The playhead, the time it is showing and the load state are driven by map
    // events rather than by the user, so they live on ``Coordinator``.
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State private var endDate = Date()
    @State private var speedFactor: Double = 1.0
    @State private var isPlaying: Bool = false

	private static let locationFinder = LocationFinder()
	@State private var locationFinderAlertIsPresented: Bool = false
	@State private var locationFinderError: LocationFinder.Error? = nil

    // detect iPad vs iPhone (or regular vs compact width)
    @Environment(\.horizontalSizeClass) private var hSizeClass

	/// Owns the map controller and every subscription this example makes, for exactly
	/// as long as the example's screen is up.
	@MainActor
	final class Coordinator: ObservableObject {
		private let _logger = Logger(type: Coordinator.self)

		/// The playhead's normalized position, as the timeline reports it.
		@Published var timelinePosition: Double = 0

		/// The time the map is currently showing.
		@Published var currentDate = Date()

		/// Whether the map has data in flight.
		@Published var isLoading = false

		/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the `MapboxMaps.MapView`.
		private(set) var mapController: DemoMapController?

		/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
		private var activeLayerCodes: Set<WeatherService.LayerCode> = []

		/// Whether the base style's place-name labels are currently hidden on behalf of an active data-query text layer.
		private var placeLabelsHidden: Bool = false

		/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
		private var eventSubscriptions: Set<AnyCancellable> = []

		/// Takes the controller back off the map when this coordinator is released.
		private var detacher: ExampleMapDetacher?

		var flyToLocation: ((CLLocationCoordinate2D, Double) -> Void)?

		/// Preload source animation data while the animated timeline is paused.
		@Published var isPreloadEnabled: Bool = false {
			didSet {
				mapController?.animationOptions.shouldPreloadData = self.isPreloadEnabled
			}
		}

		/// Wires up a controller the map view has just handed over. Safe to call again
		/// for a map that is already attached.
		func attach(
			_ mapController: DemoMapController,
			flyToLocation: @escaping (CLLocationCoordinate2D, Double) -> Void,
			dataModel: WeatherLayersModel,
			colorScheme: ColorScheme,
			startDate: Date,
			endDate: Date
		) {
			guard self.mapController == nil else {
				return
			}
			self.mapController = mapController
			self.flyToLocation = flyToLocation
			self.detacher = ExampleMapDetacher(mapController)

			// Installed before the legend is ever shown, so ``LegendControlView`` adopts
			// this control rather than creating an unstyled one.
			mapController.add(legendControl: XWLegendStyle.makeControl(colorScheme: colorScheme))

			mapController.onLoadStart.observe { [weak self] in
				self?.isLoading = true
			}.store(in: &eventSubscriptions)

			mapController.onLoadComplete.observe { [weak self] in
				self?.isLoading = false
			}.store(in: &eventSubscriptions)

			// Set up timeline range and event observers

			let timeline = mapController.timeline
			timeline.startDate = startDate
			timeline.endDate = endDate

			DispatchQueue.main.async { [weak self, weak timeline] in
				guard let self, let timeline else { return }
				self.currentDate = timeline.currentDate
				self.timelinePosition = timeline.position
			}

			timeline.onAdvance.publisher
				.receive(on: DispatchQueue.main)
				.sink { [weak self, weak timeline] _ in
					guard let self, let timeline else { return }
					self.timelinePosition = timeline.position
					self.currentDate = timeline.currentDate
				}
				.store(in: &eventSubscriptions)

			// Once the map has completed initial load…

			mapController.onLoad.observe { [weak self, weak mapController] _ in
				guard let self, let mapController else { return }

				WeatherLayerCatalog.shared.load(service: mapController.service)

				// Start listening to Combine-provided change events of the `dataModel`'s selected layers.
				dataModel.$selectedLayerCodes.sink { [weak self, weak mapController] selectedLayerCodes in
					guard let self, let mapController else { return }
					self.apply(selectedLayerCodes: selectedLayerCodes, to: mapController)
				}
				.store(in: &self.eventSubscriptions)
			}.store(in: &eventSubscriptions)
		}

		/// Adds and removes weather layers so the map matches `selectedLayerCodes`.
		private func apply(
			selectedLayerCodes: Set<WeatherService.LayerCode>,
			to mapController: DemoMapController
		) {
			// Remove any layers that are no longer selected.
			let layerCodesToRemove = activeLayerCodes.subtracting(selectedLayerCodes)
			if !layerCodesToRemove.isEmpty {
				_logger.debug("Removing layers: \(layerCodesToRemove)")
				for code in layerCodesToRemove {
					mapController.removeWeatherLayer(for: code)
				}
			}

			// Construct the configuration for and add any layers that are newly selected.

			// Each layer is inserted above the last, so the order additions are applied
			// in is the order they stack. A `Set` has none; sorting gives the same
			// stack on every launch, and the one a capture asked for.
			let layerCodesToAdd = selectedLayerCodes.subtracting(activeLayerCodes)
				.sorted { ExampleCaptureMode.stackRank(of: $0) < ExampleCaptureMode.stackRank(of: $1) }
			if !layerCodesToAdd.isEmpty {
				_logger.debug("Adding layers: \(layerCodesToAdd)")

				for code in layerCodesToAdd {
					do {
						if let layer = WeatherLayerCatalog.shared.layersByCode[code] {
							let beforeLayerId = DemoMapProvider.weatherLayerInsertBeforeId(for: mapController, layerCode: code)
							try mapController.addWeatherLayer(for: layer.code, beforeId: beforeLayerId)
						}
					} catch {
						_logger.error("Failed to add weather layer: \(error)")
					}
				}
			}

			activeLayerCodes = selectedLayerCodes

			// Hide the base style's place-name labels while a data-query text layer is active, since the two visually compete.
			let shouldHidePlaceLabels = selectedLayerCodes.contains { $0.isDataQueryTextLayer }
			if placeLabelsHidden != shouldHidePlaceLabels {
				DemoMapProvider.setPlaceLabelLayersVisible(!shouldHidePlaceLabels, for: mapController)
				placeLabelsHidden = shouldHidePlaceLabels
			}
		}
	}

	@StateObject
	private var coordinator = Coordinator()

	/// Follows the system appearance, so the basemap restyles when it changes.
	@Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var mapContent: some View {
        ZStack {
            DemoSwiftUIMapView(
                colorScheme: colorScheme,
                initialCenter: ExampleCaptureMode.camera?.center ?? .geographicCenterOfContiguousUSA,
                initialZoom: ExampleCaptureMode.camera?.zoom ?? initialZoom
            ) { mapController, flyToLocation in
                coordinator.attach(
                    mapController,
                    flyToLocation: flyToLocation,
                    dataModel: dataModel,
                    colorScheme: colorScheme,
                    startDate: startDate,
                    endDate: endDate
                )
            }
            .ignoresSafeArea()
            .onChange(of: colorScheme) { newValue in
                guard let legendControl = coordinator.mapController?.legendControl else { return }
                XWLegendStyle.apply(to: legendControl, colorScheme: newValue)
            }
            .alert(isPresented: $locationFinderAlertIsPresented, error: self.locationFinderError) {
                Button("OK") {
                    self.locationFinderError = nil
                }
            }
            .dataInspectorOverlay(mapControllerProvider: { coordinator.mapController })
            .ignoresSafeArea()

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    // Clears the floating back button ``ExampleContainer`` draws.
                    layersButton
                        .padding(.top, ExampleChrome.controlsTopInset)
                        .padding(.horizontal, ExampleChrome.horizontalPadding)
                    legendButton
                        .padding(.top, XWSpace.x2)
                        .padding(.horizontal, ExampleChrome.horizontalPadding)
                    Spacer()
                }
                Spacer()
                VStack(spacing: 0) {
                    // Sits on the back button's row, opposite it.
                    currentLocationButton
                        .padding(.top, ExampleChrome.topPadding)
                        .padding(.horizontal, ExampleChrome.horizontalPadding)
                    Spacer()
                }
            }

            LayerSidebarView(dataModel: dataModel,
                        isSidebarVisible: $isSidebarVisible)
        }
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
            get: { coordinator.timelinePosition },
            set: { newValue in
                coordinator.timelinePosition = newValue
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
            currentDate: $coordinator.currentDate,
            selectedSpeed: speedFactorBinding,
            isPlaying: isPlayingBinding,
            isLoading: $coordinator.isLoading,
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
                                    .padding([.bottom, .trailing], XWSpace.x6)
                            }
                            timeline
                                .frame(maxWidth: 360)
                                .xwOverlayCard(
                                    horizontalPadding: XWSpace.x2,
                                    verticalPadding: XWSpace.x2
                                )
                                .padding([.bottom, .trailing], XWSpace.x4)
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
                                        .padding(.horizontal, XWSpace.x4)
                                        .padding(.bottom, XWSpace.x8)
                                }
                            }
                        }
                    }
                    timeline
                        .background(XWColor.backgroundPrimary)
                        .overlay(alignment: .top) { XWDivider(color: XWColor.border) }
                }
            }

            LayerSidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            $startDate.wrappedValue = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            $endDate.wrappedValue = Date()
            coordinator.currentDate = Date()
        }
	}

	var layersButton: some View {
        CircularIconButton(systemName: "square.stack.3d.up", action: {
            self.isSidebarVisible.toggle()
        })
        .xwShadow(XWShadow.md)
        .accessibilityLabel("Weather layers")
	}

	var currentLocationButton: some View {
        // `locationFinder` is app-scoped and holds a pending callback until it fires,
        // so neither closure captures the view.
        CircularIconButton(systemName: "location", action: {
            Self.locationFinder.findCurrentLocation { [weak coordinator] location in
                coordinator?.flyToLocation?(location.coordinate, currentLocationZoom)
            } failure: { [error = $locationFinderError, isPresented = $locationFinderAlertIsPresented] failure in
                error.wrappedValue = failure
                isPresented.wrappedValue = true
            }
        })
        .xwShadow(XWShadow.md)
        .accessibilityLabel("Go to current location")
	}

    var legendButton: some View {
        CircularIconButton(systemName: "list.bullet.rectangle", action: {
            self.isLegendShown.toggle()
        })
        .xwShadow(XWShadow.md)
        .accessibilityLabel("Legend")
    }
}

#Preview {
	LayerBrowserExample()
}
