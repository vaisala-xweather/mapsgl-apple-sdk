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

/// A map controller implementation using the MapboxMaps SDK.
///
/// `MapboxMapController` integrates MapsGL rendering layers with a `MapboxMaps.MapboxMap`
/// and provides lifecycle management for adding, removing, and reordering custom layers.
///
/// It supports custom renderer integration through `MapboxLayerHost` and
/// `MapboxMaps.CustomLayer`, allowing MapsGL-compatible content to be rendered
/// atop a Mapbox-based map.
///
/// The controller ensures proper layer synchronization and defers operations
/// until the style is fully loaded to avoid premature access errors.
public final class MapboxMapController : MapController<MapboxMaps.MapboxMap> {	
	private var mapboxCancellables: Set<AnyCancellable> = []
	
	/// Creates a `MapboxMapController` from a `MapboxMaps.MapView`.
	/// - Parameters:
	///   - map: The map view instance.
	///   - account: The associated Xweather account.
	public convenience init(map: MapboxMaps.MapView, account: XweatherAccount) {
		self.init(map: map.mapboxMap, window: map.window, account: account)
	}
	
	/// Initializes the map controller with a Mapbox map, optional window, and account.
	/// - Parameters:
	///   - map: The underlying Mapbox map instance.
	///   - window: An optional window for context.
	///   - account: The associated Xweather account.
	public override init(map: MapboxMaps.MapboxMap, window: UIWindow? = nil, account: XweatherAccount) {
		super.init(map: map, window: window, account: account)
	}
	
	// MARK: MapController
	
	/// Moves a map layer beneath another layer by ID.
	/// - Parameters:
	///   - id: The ID of the layer to move.
	///   - beforeId: The ID of the layer to move below.
	/// - Throws: An error if the move operation fails.
	override public func moveLayer(id: String, beforeId: String) throws {
		try super.moveLayer(id: id, beforeId: beforeId)
		try map.moveLayer(withId: id, to: .below(beforeId))
	}
	
	// MARK: Layer Hosts
	
	/// Adds a custom rendering layer to the map.
	/// - Parameters:
	///   - layer: The layer to add.
	///   - beforeId: Optional ID of the layer to insert beneath.
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
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	/// Removes a previously added custom layer from the map.
	/// - Parameter layer: The layer to remove.
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
			} catch {
				Logger.map.fault("Failed to remove layer from map: \(error)")
			}
		}
	}
	
	/// Requests the map view to trigger a repaint.
	public override func didRequestRedraw() {
		self.map.triggerRepaint()
	}
	
	/// Sets up event handlers and emits a map load event once the style has loaded.
	public override func setUpEvents() {
		doEnsuringStyleLoaded {
			self.trigger(event: MapEvents.Load())
			self.onLoad.send(())
		}
	}
}

// MARK: Utility

extension MapboxMapController {
	/// Executes the given closure once the map's style has fully loaded.
	/// - Parameter closure: The block to run once the style is ready.
	private func doEnsuringStyleLoaded(_ closure: @escaping () -> Void) {
		if self.map.isStyleLoaded {
			closure()
		} else {
			self.map.onStyleLoaded.observeNext { [weak self] _ in
				guard self != nil else { return }
				closure()
			}.store(in: &mapboxCancellables)
		}
	}
}
