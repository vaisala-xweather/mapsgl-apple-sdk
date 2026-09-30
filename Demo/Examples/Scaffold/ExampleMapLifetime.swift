//
//  ExampleMapLifetime.swift
//  Demo
//

import Foundation
import MapsGLMaps
import OSLog

extension DemoMapController {
    /// Takes everything this controller put on the map back off, and stops the work
    /// it still has running.
    ///
    /// Called when an example's screen goes away, so its map's tiles and GPU
    /// resources are released there rather than whenever the last reference to the
    /// controller happens to drop. Idempotent.
    @MainActor
    func detachFromExample() {
        timeline.stop()

        removeDataInspectorControl()
        removeLegendControl()

        // By code rather than by layer id: a `-text` layer and the layer it samples
        // come off in dependency order that way.
        for id in weatherLayerIds {
            guard let code = WeatherService.LayerCode(rawValue: id) else {
                continue
            }
            removeWeatherLayer(for: code)
        }

        // Then whatever the example added directly.
        for id in layerIds {
            removeLayer(id: id)
        }
        for id in sourceIds {
            removeSource(id: id)
        }
    }
}

/// Calls ``DemoMapController/detachFromExample()`` when the object holding it goes
/// away.
///
/// A `@MainActor` owner cannot do that from its own `deinit`, which carries no actor
/// isolation and so cannot reach the owner's isolated state. This one can, and hops
/// to the main actor to finish.
final class ExampleMapDetacher {
    private let mapController: DemoMapController

    init(_ mapController: DemoMapController) {
        self.mapController = mapController
    }

    deinit {
        let mapController = self.mapController
        Task { @MainActor in
            mapController.detachFromExample()
            ExampleLeakCheck.expectRelease(of: mapController, named: "\(type(of: mapController))")
        }
    }
}

/// Debug-time check that an example let go of its map controller.
enum ExampleLeakCheck {
    /// Logs a fault if `object` is still alive `delay` seconds from now.
    ///
    /// Compiled out of release builds. `object` is held weakly.
    static func expectRelease(
        of object: AnyObject,
        named name: String,
        after delay: TimeInterval = 3
    ) {
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak object] in
            guard object != nil else {
                return
            }
            Logger(type: ExampleLeakCheck.self).fault(
                "\(name, privacy: .public) outlived its example — something still holds it."
            )
        }
        #endif
    }
}
