//
//  MapboxMapController.swift
//  MapsGL Prototype
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
@_spi(Experimental) import MapboxMaps // SPI Experimental req'd for `MapboxMaps.CustomLayer`

public final class MapboxMapController : MapController<MapboxMaps.MapboxMap>
{
	private lazy var _logger = Logger(for: self)
	
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
				guard !containsLayerHost(forId: layer.id) && !self.map.layerExists(withId: layer.id) else { return }
				
				// Create the `MapboxLayerHost` (with the `MapsGLLayer`), and add to the superclass `MapController`.
				let layerHost = try MapboxLayerHost(map: self.map, layer: layer)
				try addLayerHost(layerHost)
				
				// Create the `MapboxMaps.CustomLayer` (with the `MapboxLayerHost`), and add to the `MapboxMaps.MapboxMap`.
				let positionAndSlot: (position: MapboxMaps.LayerPosition, slot: MapboxMaps.Slot?) = if let beforeId {
					( .below(beforeId), nil )
				} else {
					( .default, .top )
				}
				let mapboxCustomLayer = MapboxMaps.CustomLayer(id: layer.id, renderer: layerHost, slot: positionAndSlot.slot)
				try self.map.addLayer(mapboxCustomLayer, layerPosition: positionAndSlot.position)
			}
			catch {
				_logger.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	public override func removeFromMap(layer: any MapsGLLayer) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			
			do {
				// Remove the `MapboxMaps.CustomLayer` from the `MapboxMaps.MapboxMap`.
				if self.map.layerExists(withId: layer.id) {
					try self.map.removeLayer(withId: layer.id)
				}
				
				// Remove the `MapboxLayerHost` from the superclass `MapController`.
				try removeLayerHost(id: layer.id)
			}
			catch {
				_logger.fault("Failed to remove layer from map: \(error)")
			}
		}
	}
	
	public override func didRequestRedraw() {
		self.map.triggerRepaint()
	}
	
	public override func setUpEvents() {
		doEnsuringStyleLoaded {
			self.trigger(event: MapEvents.Load())
		}
	}
}

// MARK: Utility

extension MapboxMapController
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
