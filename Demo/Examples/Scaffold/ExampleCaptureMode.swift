//
//  ExampleCaptureMode.swift
//  Demo
//

import CoreLocation
import Foundation
import MapsGLMaps
import OSLog
import UIKit

/// Opens the app straight to one example, given its slug on the command line.
///
/// Handy when you are iterating on a single example, and it is how
/// `scripts/capture-example-screenshots` drives the app: launch once per example,
/// wait for the ready line, take a screenshot, quit.
///
/// Launch arguments, read through `UserDefaults`:
///
/// - `-example <slug>` — the example to open. Without it everything here is inert.
/// - `-exampleQuietSeconds <n>` — how long loading has to stay finished before the
///   map counts as ready. Default 2.5.
/// - `-exampleSilenceSeconds <n>` — how long to wait when an example never reports
///   loading at all. Default 12.
/// - `-exampleReadyDeadline <n>` — report ready after this long regardless.
///   Default 30.
/// - `-exampleOrientation landscape|portrait` — rotate to this before drawing.
///   Left alone by default, so the device keeps whatever orientation it is in.
/// - `-exampleHideControls YES` — drop the back button and every control panel, so
///   a screenshot shows what the example draws rather than how you drive it.
///   Legends stay: they explain the map.
/// - `-exampleLayers <codes>` — comma-separated weather layer codes for the layer
///   browser to open on, in place of its own default selection. They stack in the
///   order given, so the last one draws on top.
/// - `-exampleCamera <lat>,<lon>,<zoom>` — where the map starts, in place of the
///   example's own framing.
enum ExampleCaptureMode {
    /// The slug passed on the command line, if any.
    static let slug: String? = {
        guard let slug = UserDefaults.standard.string(forKey: "example"), !slug.isEmpty else {
            return nil
        }
        return slug
    }()

    /// The example to open, or `nil` to start on the list as usual.
    static let example: Example? = {
        guard let slug = slug else {
            return nil
        }

        let match = ExampleCatalog.categories
            .flatMap { $0.examples }
            .first { $0.slug == slug }

        if match == nil {
            Logger(type: ExampleCaptureMode.self).error("No example with slug \"\(slug)\"; starting on the list.")
        }

        return match
    }()

    /// Printed once per launch, when the example's map has settled. The capture
    /// script watches for this line, and reads the safe-area insets off it to crop
    /// the device's own chrome — the Dynamic Island reserves one of them, and no
    /// `simctl` option removes it from the framebuffer.
    static let readyMarker = "MAPSGL-CAPTURE-READY"

    /// Whether to leave out the back button and the examples' control panels.
    static let hidesControls: Bool = slug != nil && UserDefaults.standard.bool(forKey: "exampleHideControls")

    /// The weather layers the layer browser should open on, bottom to top, or `nil`
    /// to leave it on its own default selection.
    static let layerCodes: [WeatherService.LayerCode]? = {
        guard slug != nil, let list = UserDefaults.standard.string(forKey: "exampleLayers") else {
            return nil
        }

        let names = list.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var codes: [WeatherService.LayerCode] = []
        for name in names {
            if let code = WeatherService.LayerCode(rawValue: name), !codes.contains(code) {
                codes.append(code)
            }
        }

        if codes.count < names.count {
            let unknown = Set(names).subtracting(codes.map(\.rawValue))
            Logger(type: ExampleCaptureMode.self).error("Ignoring unknown layer codes: \(unknown.sorted().joined(separator: ", "))")
        }

        return codes.isEmpty ? nil : codes
    }()

    /// Where `code` sits in ``layerCodes``, for putting a set of layers back into the
    /// order they were asked for. Anything unlisted sorts after, by code.
    static func stackRank(of code: WeatherService.LayerCode) -> (Int, String) {
        (layerCodes?.firstIndex(of: code) ?? .max, code.rawValue)
    }

    /// Where the map should start, or `nil` to leave an example on its own framing.
    static let camera: Camera? = {
        guard slug != nil, let value = UserDefaults.standard.string(forKey: "exampleCamera") else {
            return nil
        }

        let parts = value.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 3 else {
            Logger(type: ExampleCaptureMode.self).error("Expected -exampleCamera <lat>,<lon>,<zoom>; got \"\(value)\".")
            return nil
        }

        return Camera(
            center: CLLocationCoordinate2D(latitude: parts[0], longitude: parts[1]),
            zoom: parts[2]
        )
    }()

    /// A map framing read off the command line.
    struct Camera {
        let center: CLLocationCoordinate2D
        let zoom: Double
    }

    /// Starts the clocks. Call once, when the example's screen appears.
    ///
    /// Two of them, because an example can fail to settle in two opposite ways.
    /// One that draws only inline geometry, or hosts its own map instead of
    /// ``ExampleMapView``, never reports loading at all; one with an autoplaying
    /// timeline reports it forever. The silence fallback catches the first, the
    /// deadline the second.
    ///
    /// Main thread only.
    static func didOpenExample() {
        guard slug != nil, !didStart else {
            return
        }
        didStart = true

        after(silenceSeconds) {
            guard !didReportLoadState else {
                return
            }
            signalReady()
        }

        after(deadlineSeconds) { signalReady() }

        applyPreferredOrientation()
    }

    /// Reports the map's load state. Ready means loading finished and stayed
    /// finished, which is the only thing separating a drawn map from one that is
    /// still fetching tiles.
    ///
    /// Main thread only.
    static func didChangeLoadState(isLoading: Bool) {
        guard slug != nil, !didSignal else {
            return
        }
        didReportLoadState = true

        // Any change restarts the quiet period, so a burst of loads counts once.
        quietGeneration += 1
        guard !isLoading else {
            return
        }

        let generation = quietGeneration
        after(quietSeconds) {
            guard generation == quietGeneration else {
                return
            }
            signalReady()
        }
    }

    // MARK: - Private

    private static let quietSeconds = seconds(forKey: "exampleQuietSeconds", default: 2.5)
    private static let silenceSeconds = seconds(forKey: "exampleSilenceSeconds", default: 12)
    private static let deadlineSeconds = seconds(forKey: "exampleReadyDeadline", default: 30)

    private static var quietGeneration = 0
    private static var didStart = false
    private static var didReportLoadState = false
    private static var didSignal = false

    private static func seconds(forKey key: String, default fallback: TimeInterval) -> TimeInterval {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : fallback
    }

    private static func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// The left and right safe-area insets in device pixels. The map draws under
    /// them, so cropping them off removes the Dynamic Island without losing any of
    /// the example.
    private static func horizontalSafeAreaPixels() -> (leading: Int, trailing: Int) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow ?? $0.windows.first }
            .first

        guard let window = window else {
            return (0, 0)
        }

        let scale = window.screen.scale
        let insets = window.safeAreaInsets
        return (Int((insets.left * scale).rounded()), Int((insets.right * scale).rounded()))
    }

    /// Rotates the device, so a capture run does not depend on which way the
    /// simulator happened to be left. `simctl` cannot rotate; the app can.
    private static func applyPreferredOrientation() {
        let orientations: UIInterfaceOrientationMask
        switch UserDefaults.standard.string(forKey: "exampleOrientation") {
        case "landscape":
            orientations = .landscapeRight
        case "portrait":
            orientations = .portrait
        default:
            return
        }

        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        }
    }

    private static func signalReady() {
        guard !didSignal, let slug = slug else {
            return
        }
        didSignal = true

        let insets = horizontalSafeAreaPixels()
        print("\(readyMarker) \(slug) insets=\(insets.leading),\(insets.trailing)")
        fflush(stdout)
    }
}
