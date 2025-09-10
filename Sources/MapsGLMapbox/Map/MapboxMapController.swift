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

/// Protocol that can be implemented to allow deciding which slot to insert Mapbox layers into when using the "Standard" styles
public protocol MapboxLayerSlotProviding {
	func slot(for layer: MapboxMaps.Layer, on map: MapboxMaps.MapboxMap) -> MapboxMaps.Slot?
}

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
	public struct SlotProvider: MapboxLayerSlotProviding {
		public typealias Resolver = (_ layer: MapboxMaps.Layer, _ map: MapboxMaps.MapboxMap) -> MapboxMaps.Slot?
		private let resolver: Resolver
		
		public init(_ resolver: @escaping Resolver) { self.resolver = resolver }
		
		public func slot(for layer: MapboxMaps.Layer, on map: MapboxMaps.MapboxMap) -> MapboxMaps.Slot? {
			resolver(layer, map)
		}
	}
	
	/// Returns which slot to insert Mapbox layers into when using the "Standard" Mapbox styles
	public var slotProvider: MapboxLayerSlotProviding?
	
	private var isStyleLoaded: Bool = false
	private var mapboxCancellables: Set<AnyCancellable> = []
	
	/// Stores layers waiting for their source to be added once initial metadata loads
	private var pendingLayersBySource: [String: [(layer: Layer, position: LayerPosition)]] = [:]
	
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
		
		self.map.onStyleLoaded.observe { [weak self] loaded in
			guard let self = self else { return }
			self.updateMaskLayersForMap()
		}.store(in: &mapboxCancellables)
		
		self.isStyleLoaded = self.map.isStyleLoaded
		initialize()
	}
	
	public override func initialize() {
		doEnsuringStyleLoaded {
			super.initialize()
		}
	}
	
	// MARK: MapController
	
	/// Moves a map layer beneath another layer by ID.
	/// - Parameters:
	///   - id: The ID of the layer to move.
	///   - beforeId: The ID of the layer to move below.
	/// - Throws: An error if the move operation fails.
	override public func moveLayer(id: String, beforeId: String?) throws {
		try super.moveLayer(id: id, beforeId: beforeId)
		if let beforeId {
			try map.moveLayer(withId: id, to: .below(beforeId))
		} else {
			try map.moveLayer(withId: id, to: .default)
		}
	}
	
	override public func beforeIdForMaskLayers() -> String? {
		// Layers can't be referenced by id when using Mapbox's "Standard" styles, so return nil here as mask layers will be 
		// automatically inserted into the .bottom slot in `addToMap`.
		if let styleURI = self.map.styleURI, styleURI.rawValue.contains("mapbox/standard") {
			return nil
		} else if self.map.layerExists(withId: "hillshade") {
			return "hillshade"
		}
		return "land-structure-polygon"
	}
	
	override public func updateMaskLayersForMap() {
		do {
			try self.masks.forEach { (kind, layer) in
				var layerId: String? 
				switch kind {
				case .land:
					layerId = "land"
				default:
					break
				}
				
				if let layerId = layerId {
					let propertyValue = self.map.layerProperty(for: layerId, property: "background-color")
					try self.map.setLayerProperty(for: layer.id, property: "fill-color", value: propertyValue.value)
				}
			}
		} catch {
			Logger.map.error(error.localizedDescription)
		}
	}
	
	// MARK: Layer Hosts
	
	/// Adds a MapsGL data source to the Mapbox map.
	/// - Parameters:
	///    - source: The source to add.
	///    - onSourceAdded: A function to call when the source has been added to Mapbox.
	public override func addToMap(source: some DataSource, onSourceAdded: (() -> Void)? = nil) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			
			do {
				guard !self.map.sourceExists(withId: source.id) else { return }
				
				// Create the Mapbox data source
				switch source {
				case let source as MapsGLMaps.VectorTileSource:
					let adapter = MapboxVectorSourceAdapter(source: source, map: self.map)
					Task { @MainActor in
						let customSource = await adapter.makeSource()
						source.setInvalidateFunction(adapter.invalidate)					
						try self.map.addSource(customSource)
						onSourceAdded?()
					}
				case let source as MapsGLMaps.GeoJSONSource:
					var mapboxSource = MapboxMaps.GeoJSONSource(id: source.id)
					if let data = source.data {
						mapboxSource.data = .featureCollection(data)
					} else if let dataURL = source.makeDataURL() {
						mapboxSource.data = .url(dataURL)
					}
					try self.map.addSource(mapboxSource)
					onSourceAdded?()
				default: break
				}
			} catch {
				Logger.map.fault("Failed to add source to map: \(error)")
			}
		}
	}
	
	/// Adds a MapsGL layer to the Mapbox map.
	/// - Parameters:
	///   - layer: The layer to add.
	///   - beforeId: Optional ID of the layer to insert beneath.
	public override func addToMap(layer: any MapsGLLayer, beforeId: String?) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			guard !self.map.layerExists(withId: layer.id) else { return }
			
			do {
				switch layer {
				case let vectorTileLayer as MapsGLMaps.VectorTileLayer:	
					var style = vectorTileLayer.paint.asStyleJSON(id: vectorTileLayer.id, source: vectorTileLayer.source.id, sourceLayer: vectorTileLayer.sourceLayer)
					style.filter = vectorTileLayer.filter
					
					let styleJSON = style.asStyleJSONObject()
					var mapboxLayer: Layer?
					var layerSlot: MapboxMaps.Slot?
					
					// Automatically add MapsGL mask layers into the .bottom slot. This can be overriden using the `slotProvider`.
					if layer.id.hasPrefix("mask::") {
						layerSlot = .bottom
					}
					
					#if DEBUG
					if let jsonData = try? JSONSerialization.data(withJSONObject: styleJSON, options: .prettyPrinted),
					   let jsonString = String(data: jsonData, encoding: .utf8) {
						print("Style JSON for layer \(vectorTileLayer.id):\n\(jsonString)")
					}
					#endif
					
					switch style.type {
					case .fill: mapboxLayer = try FillLayer(jsonObject: styleJSON)
					case .line: mapboxLayer = try LineLayer(jsonObject: styleJSON)
					case .circle: mapboxLayer = try CircleLayer(jsonObject: styleJSON)
					case .heatmap: mapboxLayer = try HeatmapLayer(jsonObject: styleJSON)
					case .symbol: mapboxLayer = try SymbolLayer(jsonObject: styleJSON)
					default:
						mapboxLayer = nil
					}
					
					if var layer = mapboxLayer {
						let positionAndSlot = layerPositionAndSlot(beforeId: beforeId, slot: slotProvider?.slot(for: layer, on: map) ?? layerSlot)
						layer.slot = positionAndSlot.slot
						
						guard self.map.sourceExists(withId: vectorTileLayer.source.id) else {
							let sourceId = vectorTileLayer.source.id
							
							// Queue this layer for adding once its source is added
							var pendingLayers = self.pendingLayersBySource[sourceId] ?? []
							pendingLayers.append((layer, positionAndSlot.position))
							self.pendingLayersBySource[sourceId] = pendingLayers
							
							// Add a temporary dummy layer so other layers that need to reference it even while it's awaiting 
							// the data source to become ready can still do so. Then remove the dummy layer and insert the actual
							// one in the event handler.
							var dummyLayer = BackgroundLayer(id: layer.id)
							dummyLayer.slot = positionAndSlot.slot
							try self.map.addPersistentLayer(dummyLayer, layerPosition: positionAndSlot.position)
							
							if let layer = layer as? PlatformStyleLayer {
								vectorTileLayer.platformLayer = layer
							}
							
							self.onSourceAdded.publisher
								.filter { $0 == vectorTileLayer.source.id }
								.first()
								.sink { [weak self] _ in
									guard let self = self else { return }
									let pending = self.pendingLayersBySource[sourceId] ?? []
									for (pendingLayer, position) in pending {
										do {
											if self.map.layerExists(withId: pendingLayer.id) {
												try self.map.removeLayer(withId: pendingLayer.id)
											}
											try self.map.addPersistentLayer(pendingLayer, layerPosition: position)
										} catch {
											Logger.map.error("\(error)")
										}
									} 
									self.pendingLayersBySource.removeValue(forKey: sourceId)
								}
								.store(in: &self.mapboxCancellables)
							return
						}
						try self.map.addPersistentLayer(layer, layerPosition: positionAndSlot.position)
					}					
				case let metalLayer as any MapsGLMetalLayer:
					addCustomLayer(layer: metalLayer, beforeId: beforeId)
				default: break
				}
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	private func addCustomLayer(layer: some MapsGLMetalLayer, beforeId: String?) {
		guard !containsLayerHost(forId: layer.id) else { return }
		do {
			// Create the `MapboxLayerHost` (with the `MapsGLLayer`), and add to the superclass `MapController`.
			let layerHost = try MapboxLayerHost(map: self.map, layer: layer)
			try addLayerHost(layerHost)
			
			let positionAndSlot = layerPositionAndSlot(beforeId: beforeId)
			var mapboxCustomLayer = MapboxMaps.CustomLayer(id: layer.id, renderer: layerHost, slot: positionAndSlot.slot)
			mapboxCustomLayer.slot = slotProvider?.slot(for: mapboxCustomLayer, on: map)
			try self.map.addPersistentLayer(mapboxCustomLayer, layerPosition: positionAndSlot.position)
		} catch {
			
		}
	}
	
	private func layerPositionAndSlot(beforeId: String?, slot: MapboxMaps.Slot? = nil) -> (position: MapboxMaps.LayerPosition, slot: MapboxMaps.Slot?) {
		if let beforeId {
			 return ( .below(beforeId), slot )
		} else {
			return ( .default, slot )
		}
	}
	
	public override func removeFromMap(source: any DataSource) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			
			do {
				if let source = source as? VectorTileSource, self.map.sourceExists(withId: source.id) {
					try self.map.removeSource(withId: source.id)
				}
			} catch {
				Logger.map.fault("Failed to remove source from map: \(error)")
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
			self.loadStyles()
		}
	}
}

// MARK: Utility

extension MapboxMapController {
	/// Executes the given closure once the map's style has fully loaded.
	/// - Parameter closure: The block to run once the style is ready.
	private func doEnsuringStyleLoaded(_ closure: @escaping () -> Void) {
		if self.isStyleLoaded {
			Task { @MainActor in
				closure()
			}
		} else {
			self.map.onStyleLoaded.observeNext { [weak self] _ in
				guard self != nil else { return }
				self?.isStyleLoaded = true
				Task { @MainActor in
					closure()
				}
			}.store(in: &mapboxCancellables)
		}
	}
}

extension MapboxMaps.MapboxMap: @retroactive ImageRegisteringMap {
	public func addImage(id: String, image: UIImage, sdf: Bool) throws {
		Task { @MainActor in
			try self.addImage(image, id: id, sdf: sdf)
		}
	}
}
