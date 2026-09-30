//
//  ExampleMapView.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// The map scaffold most examples are built on.
///
/// Owns the parts that are identical in each example — creating the
/// ``DemoMapController``, waiting for its initial load, holding the Combine
/// subscriptions, and showing a loading indicator — so an example file contains
/// only the API it is demonstrating.
///
/// `onLoad` is the whole of this view's contract with the SDK, and it is one call:
///
/// ```swift
/// mapController.onLoad.observe { _ in
///     // …the closure passed as `onLoad`
/// }.store(in: &subscriptions)
/// ```
///
/// It runs once, on the main actor, after the map's first load completes — the
/// point at which the style exists and a weather layer added against it will
/// stick. Store anything else subscribed to in the bag it hands back; the bag is
/// released with the view, and the controller is detached from the map at the same
/// point. Capture `[weak mapController]` in anything stored there.
///
/// ``DisplayAWeatherMapExample`` writes that out longhand, without this scaffold.
struct ExampleMapView<Overlay: View>: View {
    /// Where the camera starts. Defaults to the contiguous United States.
    var center: CLLocationCoordinate2D = .geographicCenterOfContiguousUSA

    /// Initial zoom level.
    var zoom: Double = 2.75

    /// Called once, when the controller's `onLoad` fires.
    let onLoad: (DemoMapController, inout Set<AnyCancellable>) -> Void

    /// Controls drawn over the map, e.g. a legend or a slider.
    @ViewBuilder var overlay: (DemoMapController?) -> Overlay

    @StateObject private var model = ExampleMapModel()

    /// Follows the system appearance, so the basemap restyles when it changes.
    @Environment(\.colorScheme) private var colorScheme

    init(
        center: CLLocationCoordinate2D = .geographicCenterOfContiguousUSA,
        zoom: Double = 2.75,
        onLoad: @escaping (DemoMapController, inout Set<AnyCancellable>) -> Void,
        @ViewBuilder overlay: @escaping (DemoMapController?) -> Overlay
    ) {
        self.center = center
        self.zoom = zoom
        self.onLoad = onLoad
        self.overlay = overlay
    }

    var body: some View {
        ZStack {
            DemoSwiftUIMapView(
                colorScheme: colorScheme,
                initialCenter: ExampleCaptureMode.camera?.center ?? center,
                initialZoom: ExampleCaptureMode.camera?.zoom ?? zoom,
                // Only the scale bar moves, to clear the back button
                // ``ExampleContainer`` floats top-leading. The logo and attribution
                // stay at the map's edge; the overlay is lifted above them instead.
                //
                // A capture is framed inside a phone illustration that crops a few
                // points off each edge, so attribution comes in far enough to stay
                // legible there.
                ornamentInsets: .init(
                    top: ExampleChrome.controlsTopInset,
                    bottom: ExampleCaptureMode.hidesControls ? XWSpace.x4 : 0
                )
            ) { mapController, flyTo in
                model.attach(mapController, flyTo: flyTo, colorScheme: colorScheme, onLoad: onLoad)
            }
            .ignoresSafeArea()
            .onChange(of: colorScheme) { newValue in
                model.applyLegendStyle(colorScheme: newValue)
            }

            // Bottom-anchored controls stop above the map's logo and attribution
            // rather than covering them.
            overlay(model.mapController)
                .padding(.bottom, ExampleChrome.bottomOrnamentClearance)
        }
        .overlay(alignment: .topTrailing) { loadingIndicator }
    }

    /// Sits opposite the back button, on its row, rather than over the map.
    ///
    /// Loading is ambient here — every pan, zoom and timeline step starts one — so
    /// the indicator belongs with the chrome and not in front of the data it is
    /// about to draw.
    @ViewBuilder
    private var loadingIndicator: some View {
        if model.showsLoadingIndicator && !ExampleCaptureMode.hidesControls {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .xwCircularSurface(size: ExampleChrome.loadingIndicatorSize)
                .padding(.top, ExampleChrome.topPadding)
                .padding(.horizontal, ExampleChrome.horizontalPadding)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }
}

extension ExampleMapView where Overlay == EmptyView {
    init(
        center: CLLocationCoordinate2D = .geographicCenterOfContiguousUSA,
        zoom: Double = 2.75,
        onLoad: @escaping (DemoMapController, inout Set<AnyCancellable>) -> Void
    ) {
        self.init(center: center, zoom: zoom, onLoad: onLoad) { _ in EmptyView() }
    }
}

/// Holds the controller and subscriptions for one ``ExampleMapView``, for exactly as
/// long as the example's screen is up.
@MainActor
final class ExampleMapModel: ObservableObject {
    @Published private(set) var mapController: DemoMapController?

    /// Whether the map has been loading long enough to be worth saying so.
    @Published private(set) var showsLoadingIndicator = false

    /// Moves the camera. Available once the map is ready.
    private(set) var flyTo: ((CLLocationCoordinate2D, Double) -> Void)?

    private var subscriptions: Set<AnyCancellable> = []
    private var didAttach = false

    /// Takes the controller back off the map when this model is released.
    private var detacher: ExampleMapDetacher?

    func attach(
        _ mapController: DemoMapController,
        flyTo: @escaping (CLLocationCoordinate2D, Double) -> Void,
        colorScheme: ColorScheme,
        onLoad: @escaping (DemoMapController, inout Set<AnyCancellable>) -> Void
    ) {
        // `onAppear` can fire more than once for the same map.
        guard !didAttach else {
            return
        }
        didAttach = true

        // Ahead of publishing the controller, so this is the control a
        // ``LegendControlView`` finds rather than a default one of its own.
        mapController.add(legendControl: XWLegendStyle.makeControl(colorScheme: colorScheme))

        self.mapController = mapController
        self.flyTo = flyTo
        self.detacher = ExampleMapDetacher(mapController)

        mapController.onLoadStart.observe { [weak self] in
            self?.setLoading(true)
        }.store(in: &subscriptions)

        mapController.onLoadComplete.observe { [weak self] in
            self?.setLoading(false)
        }.store(in: &subscriptions)

        mapController.onLoad.observe { [weak self, weak mapController] _ in
            guard let self, let mapController else { return }
            onLoad(mapController, &self.subscriptions)
            // An example that adds no weather layer never reports a load, so the
            // map itself coming up is its settle point.
            self.setLoading(false)
        }.store(in: &subscriptions)
    }

    deinit {
        indicatorTask?.cancel()
    }

    /// Re-applies the legend styling that does not follow the appearance on its own.
    func applyLegendStyle(colorScheme: ColorScheme) {
        guard let legendControl = mapController?.legendControl else {
            return
        }
        XWLegendStyle.apply(to: legendControl, colorScheme: colorScheme)
    }

    /// Loading shorter than this shows nothing. Panning, zooming and each timeline
    /// step all start a load, and most finish in a few hundred milliseconds — an
    /// indicator that appears and vanishes in that time reads as a flicker rather
    /// than as progress.
    private static let indicatorDelay: TimeInterval = 0.4

    private var indicatorTask: Task<Void, Never>?

    private func setLoading(_ isLoading: Bool) {
        ExampleCaptureMode.didChangeLoadState(isLoading: isLoading)

        indicatorTask?.cancel()
        guard isLoading else {
            withAnimation(XWMotion.base) { showsLoadingIndicator = false }
            return
        }

        indicatorTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.indicatorDelay * 1_000_000_000))
            guard !Task.isCancelled, let self = self else {
                return
            }
            withAnimation(XWMotion.base) { self.showsLoadingIndicator = true }
        }
    }
}

