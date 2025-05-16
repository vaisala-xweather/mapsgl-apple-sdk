//
//  Mapbox10MapController.swift
//  MapsGLMapbox10 framework
//
//  Created by Slipp Douglas Thompson on 9/26/23.
//

import Spatial
import OSLog
import Combine
import CoreLocation
import UIKit
import MapsGLCore
import MapsGLMaps
import MapboxMaps

public final class Mapbox10MapController : MapController<MapboxMaps.MapboxMap> {
	private var _mapboxSubscriptions: Set<AnyCancellable> = []
	
	public convenience init(map: MapboxMaps.MapView, account: XweatherAccount) {
		self.init(map: map.mapboxMap, window: map.window, account: account)
	}
	
	public override init(map: MapboxMaps.MapboxMap, window: UIWindow? = nil, account: XweatherAccount) {
		super.init(map: map, window: window, account: account)
	}
	
	public override func addToMap(layer: some MapsGLLayer, beforeId: String?) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			
			do {
				guard !containsLayerHost(forId: layer.id) && !self.map.style.layerExists(withId: layer.id) else { return }
				
				// Create the `MapboxLayerHost` (with the `MapsGLLayer`), and add to the superclass `MapController`.
				let layerHost = try MapboxLayerHost(map: self.map, layer: layer)
				try addLayerHost(layerHost)
				
				// Add the `MapboxLayerHost` to the `MapboxMaps.MapboxMap`.
				let position: MapboxMaps.LayerPosition = if let beforeId {
					.below(beforeId)
				} else {
					.default
				}
				try self.map.style.addPersistentCustomLayer(withId: layer.id, layerHost: layerHost, layerPosition: position)
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	public override func removeFromMap(layer: any MapsGLLayer) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			
			do {
				// Remove the `MapboxLayerHost` from the `MapboxMaps.MapboxMap`.
				if self.map.style.layerExists(withId: layer.id) {
					try self.map.style.removeLayer(withId: layer.id)
				}
				
				// Remove the `MapboxLayerHost` from the superclass `MapController`.
				try removeLayerHost(id: layer.id)
			} catch {
				Logger.map.fault("Failed to remove layer from map: \(error)")
			}
		}
	}
	
	public override func didRequestRedraw() {
		self.map.triggerRepaint()
	}
	
	public override func setUpEvents() {
		doEnsuringStyleLoaded {
			self.trigger(event: MapEvents.Load())
			self.onLoad.send(())
		}
	}
}

// MARK: Utility

extension Mapbox10MapController
{
	private func doEnsuringStyleLoaded(_ closure: @escaping () -> Void) {
		if self.map.isStyleLoaded {
			closure()
		} else {
			self.map.onStyleLoaded.observeNext { [weak self] _ in
				guard self != nil else { return }
				closure()
			}.store(in: &_mapboxSubscriptions)
		}
	}
}
