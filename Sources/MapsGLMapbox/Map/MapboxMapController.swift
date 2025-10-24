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

/// A strategy protocol for deciding **where** a Mapbox style layer should be inserted.
///
/// Conformers can choose a slot (e.g. `.bottom`, `.middle`, `.top`) or a relative
/// position (e.g. `.below("building")`) by returning a ``MapboxMapController/Placement``.
/// Implementations may examine both the layer and the current map style.
public protocol MapboxLayerPlacementProviding {
	func placement(for layer: MapboxMaps.Layer, on map: MapboxMaps.MapboxMap) -> MapboxMapController.Placement
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
	private var isStyleLoaded: Bool = false
	private var mapboxCancellables: Set<AnyCancellable> = []
	
	/// Stores layers waiting for their source to be added once initial metadata loads
	private var pendingLayersBySource: [String: [(layer: Layer, placement: Placement)]] = [:]
	
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
			self.updateManagedLayersForStyle()
		}.store(in: &mapboxCancellables)
		
		self.isStyleLoaded = self.map.isStyleLoaded
		initialize()
	}
	
	// MARK: MapController
	
	/// Performs controller setup once the style is ready.
	///
	/// This calls `super.initialize()` within `doEnsuringStyleLoaded` to ensure that
	/// style-dependent work is deferred until the style has finished loading.
	public override func initialize() {
		doEnsuringStyleLoaded {
			super.initialize()
		}
	}
	
	/// Moves a map layer beneath another layer by ID.
	/// - Parameters:
	///   - id: The id of the layer to move.
	///   - beforeId: If non-nil, the destination layer id to move **below**; otherwise `.default` is used.
	/// - Throws: Errors thrown by Mapbox style mutation.
	override public func moveLayer(id: String, beforeId: String?) throws {
		try super.moveLayer(id: id, beforeId: beforeId)
		if let beforeId {
			try map.moveLayer(withId: id, to: .below(beforeId))
		} else {
			try map.moveLayer(withId: id, to: .default)
		}
	}
	
	// MARK: Adding/Removing MapsGL Resources
	
	/// Adds a MapsGL data source to the Mapbox style.
	/// 
	/// Vector and GeoJSON sources are bridged to their Mapbox equivalents.
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
	
	/// Adds a MapsGL layer to the Mapbox style, converting it to the appropriate Mapbox layer.
	/// - Parameters:
	///   - layer: The MapsGL layer.
	///   - beforeId: Optional id to place the layer **below**.
	public override func addToMap(layer: any MapsGLLayer, beforeId: String?) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			guard !self.map.layerExists(withId: layer.id) else { return }
			do {
				switch layer {
				case let vectorLayer as MapsGLMaps.VectorTileLayer:	
					try addMapsGLVectorLayer(layer: vectorLayer, beforeId: beforeId)				
				case let metalLayer as any MapsGLMetalLayer:
					try addMapsGLMetalLayer(layer: metalLayer, beforeId: beforeId)
				default: break
				}
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	/// Removes a previously added data source from the style.
	/// - Parameter source: The data source to remove.
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
	
	/// Removes a previously added layer from the style and from the controller’s registry.
	/// - Parameter layer: The layer to remove.
	public override func removeFromMap(layer: any MapsGLLayer) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			do {
				// Remove the `MapboxMaps.CustomLayer` from the `MapboxMaps.MapboxMap`.
				if self.map.layerExists(withId: layer.id) {
					try self.map.removeLayer(withId: layer.id)
					viewportHost?.unregister(layer: layer)
				}
				placementByLayerId.removeValue(forKey: layer.id)
				
				// Remove the `MapboxLayerHost` from the superclass `MapController`.
				try removeLayerHost(id: layer.id)
			} catch {
				Logger.map.fault("Failed to remove layer from map: \(error)")
			}
		}
	}
	
	/// Requests a style repaint on the underlying Mapbox map.
	public override func didRequestRedraw() {
		map.triggerRepaint()
	}
	
	/// Syncs mask and managed layers with the current style, re-applying cached placements as needed.
	private func updateManagedLayersForStyle() {
		do {
			try self.masks.forEach { (kind, layer) in
				var layerId: String? 
				switch kind {
				case .land:
					layerId = "land"
				default:
					break
				}
								
				if let layerId = layerId, self.map.layerExists(withId: layerId) {
					let propertyValue = self.map.layerProperty(for: layerId, property: "background-color")
					try self.map.setLayerProperty(for: layer.id, property: "fill-color", value: propertyValue.value)
				}
			}
		} catch {
			Logger.map.error("Failed to update mask layers: \(error.localizedDescription)")
		}
		
		placementByLayerId.keys.forEach { id in
			guard self.map.layerExists(withId: id) else { return }
			do {
				guard let placement = placementByLayerId[id] else { return }
				let layer = try self.map.layer(withId: id)
				try PlacementResolver.apply(placement, to: layer, in: self)
			} catch {
				Logger.map.error("Failed to update placement for layer `\(id)`: \(error.localizedDescription)")
			}
		}
	}
	
	// MARK: Viewport Sync
	
	private var viewportHost: MapboxViewportHost?
	
	// Create a tiny host that never renders—just forwards parameters.
	private func installViewportSyncLayer() throws {
		let host = MapboxViewportHost(map: self.map)
		self.viewportHost = host
		try self.map.addCustomLayer(withId: host.id, layerHost: host, layerPosition: nil)
	}

	private func removeViewportSyncLayerIfNeeded() {
		if let host = viewportHost, self.map.layerExists(withId: host.id) {
			try? self.map.removeLayer(withId: host.id)
		}
		viewportHost = nil
	}
	
	// MARK: MapsGL Layer Bridge
	
	/// Bridges a `MapsGLMetalLayer` into a `MapboxMaps.CustomLayer` and inserts it with resolved placement.
	private func addMapsGLMetalLayer(layer: some MapsGLMetalLayer, beforeId: String?) throws {
		guard !containsLayerHost(forId: layer.id) else { return }
		
		// Create the `MapboxLayerHost` (with the `MapsGLLayer`), and add to the superclass `MapController`.
		let layerHost = try MapboxLayerHost(map: self.map, layer: layer)
		try addLayerHost(layerHost)
		
		var mapboxCustomLayer = MapboxMaps.CustomLayer(id: layer.id, renderer: layerHost, slot: nil)
		let placement = PlacementResolver.make(for: mapboxCustomLayer, in: self, provider: placementProvider, beforeId: beforeId)
		let resolvedPlacement = placement.resolved(for: self.map)
		mapboxCustomLayer.slot = resolvedPlacement.slot
		try self.map.addPersistentLayer(mapboxCustomLayer, layerPosition: resolvedPlacement.position)
		placementByLayerId[mapboxCustomLayer.id] = resolvedPlacement
	}
	
	/// Bridges a `VectorTileLayer` into a concrete Mapbox style layer and inserts it with resolved placement.
	private func addMapsGLVectorLayer(layer: MapsGLMaps.VectorTileLayer, beforeId: String?) throws {
		var style = layer.paint.asStyleJSON(id: layer.id, source: layer.source.id, sourceLayer: layer.sourceLayer)
		style.filter = layer.filter
		
		let styleJSON = style.asStyleJSONObject()
		var mapboxLayer: Layer?
		
		#if DEBUG
		if let jsonData = try? JSONSerialization.data(withJSONObject: styleJSON, options: .prettyPrinted),
		   let jsonString = String(data: jsonData, encoding: .utf8) {
			print("Style JSON for layer \(layer.id):\n\(jsonString)")
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
		
		guard var mapboxLayer = mapboxLayer else { return }
		let placement = PlacementResolver.make(for: mapboxLayer, in: self, provider: placementProvider, beforeId: beforeId)
		let resolvedPlacement = placement.resolved(for: self.map)
		mapboxLayer.slot = placement.slot
		placementByLayerId[mapboxLayer.id] = placement
		
		if viewportHost == nil {
			try installViewportSyncLayer()
		}
		viewportHost?.register(layer: layer)
		
		guard self.map.sourceExists(withId: layer.source.id) else {
			let sourceId = layer.source.id
			
			// Add a temporary dummy layer so other layers that need to reference it even while it's awaiting 
			// the data source to become ready can still do so. Then remove the dummy layer and insert the actual
			// one in the event handler.
			var dummyLayer = BackgroundLayer(id: mapboxLayer.id)
			dummyLayer.slot = resolvedPlacement.slot
			try self.map.addPersistentLayer(dummyLayer, layerPosition: resolvedPlacement.position)
			
			// Queue this layer for adding once its source is added
			var pendingLayers = self.pendingLayersBySource[sourceId] ?? []
			pendingLayers.append((mapboxLayer, resolvedPlacement))
			self.pendingLayersBySource[sourceId] = pendingLayers
			
			if let platformLayer = mapboxLayer as? PlatformStyleLayer {
				layer.platformLayer = platformLayer
			}
			
			self.onSourceAdded.publisher
				.filter { $0 == layer.source.id }
				.first()
				.sink { [weak self] _ in
					guard let self = self else { return }
					let pending = self.pendingLayersBySource[sourceId] ?? []
					for (pendingLayer, pendingPlacement) in pending {
						do {
							if self.map.layerExists(withId: pendingLayer.id) {
								try self.map.removeLayer(withId: pendingLayer.id)
							}
							try self.map.addPersistentLayer(pendingLayer, layerPosition: pendingPlacement.position)
						} catch {
							Logger.map.error("\(error)")
						}
					} 
					self.pendingLayersBySource.removeValue(forKey: sourceId)
				}
				.store(in: &self.mapboxCancellables)
			return
		}
		try self.map.addPersistentLayer(mapboxLayer, layerPosition: resolvedPlacement.position)
	}
	
	// MARK: Layer Placement
	
	private var placementByLayerId: [String: Placement] = [:]
	
	/// Describes the desired **placement** of a Mapbox style layer.
	///
	/// Placement is the combination of:
	/// - ``position``: a `LayerPosition` such as `.default`, `.below(id)`, `.above(id)`; and
	/// - ``slot``: an optional `Slot` used by styles that define slot regions.
	public struct Placement {
		/// A relative position in the layer stack (default/above/below).
		public var position: MapboxMaps.LayerPosition
		/// The target slot (if the active style supports slots).
		public var slot: MapboxMaps.Slot?
		
		/// Creates a placement with an optional slot and a position (defaults to `.default`).
		/// - Parameters:
		///   - position: Where the layer should be inserted relative to others.
		///   - slot: A style slot to target, if available in the current style.
		public init(position: MapboxMaps.LayerPosition = .default, slot: MapboxMaps.Slot? = nil) {
			self.position = position
			self.slot = slot
		}
		
		/// Resolves this placement against the current style, returning an adjusted copy.
		///
		/// Resolution rules:
		/// - If ``position`` is `.above(id)` or `.below(id)` and the referenced `id` exists,
		///   the resulting slot is coerced to match that layer’s slot (for slotted styles).
		/// - If the referenced `id` does **not** exist, the position falls back to `.default`.
		/// - If ``slot`` is non-nil but the active style does not define that slot
		///   (see `MapboxMap.allSlotIdentifiers`), the slot is cleared to `nil`.
		///
		/// - Parameter map: The map whose current style is used for resolution.
		/// - Returns: A copy of `Placement` that is valid for the active style.
		public func resolved(for map: MapboxMaps.MapboxMap) -> Placement {
			var resolved = self
			
			switch resolved.position {
			case .above(let id):
				fallthrough
			case .below(let id):
				// For Mapbox styles that contain slots, layers inserted relative to another layer need to be 
				// added to the same slot. So get the slot for the associated layer if it exists and use it instead.
				if map.layerExists(withId: id) {
					do {
						let layer = try map.layer(withId: id)
						resolved.slot = layer.slot
					} catch {
						Logger.map.error("Failed to retrieve layer slot for `\(id)`: \(error)")
					}
				} else {
					resolved.position = .default
				}
			default: break
			}
			
			// If the style does not advertise the chosen slot, ignore it to avoid errors.
			if let slot = resolved.slot, map.allSlotIdentifiers.contains(slot) == false {
				resolved.slot = nil
			}
			
			return resolved
		}
	}
	
	/// A convenience implementation that wraps a closure for computing placement. Useful for quick customization 
	/// without defining a separate type.
	public struct PlacementProvider: MapboxLayerPlacementProviding {
		public typealias Resolver = (_ layer: MapboxMaps.Layer, _ map: MapboxMaps.MapboxMap) -> Placement
		private let resolver: Resolver
		
		public init(_ resolver: @escaping Resolver) { self.resolver = resolver }
		
		public func placement(for layer: MapboxMaps.Layer, on map: MapboxMaps.MapboxMap) -> Placement {
			resolver(layer, map)
		}
	}
	
	/// Default placement strategy.
	///
	/// By default, MapsGL mask layers (ids prefixed with `mask::`) are positioned
	/// below the `building` layer and assigned the `.bottom` slot when available.
	/// Provide your own `placementProvider` to override this behavior.
	public var placementProvider: MapboxLayerPlacementProviding? = PlacementProvider { layer, map in
		var placement = Placement()
		if layer.id.hasPrefix("mask::") {
			if layer.id.hasSuffix("::land") || layer.id.hasSuffix("::water") {
				placement.position = .below("building")
				placement.slot = .bottom
			}
		}
		return placement
	}
}

// MARK: Utility

extension MapboxMapController {
	/// Executes a closure once the Mapbox style is loaded, immediately if already loaded.
	/// Ensures callbacks are invoked on the main actor.
	private func doEnsuringStyleLoaded(_ closure: @escaping () -> Void) {
		if self.isStyleLoaded {
			Task { @MainActor in
				closure()
			}
		} else {
			self.map.onStyleLoaded.observe { [weak self] _ in
                guard self != nil,
                      self?.isStyleLoaded == false else { return }
				self?.isStyleLoaded = true
				Task { @MainActor in
					closure()
				}
			}.store(in: &mapboxCancellables)
            
            // map.isStyleLoaded is `false` if custom data sources or layer resources are being loaded, which prevents
            // this internal `isStyleLoaded` flag from ever being set to true if the MapsGL map controller is instantiated
            // immedately after custom data sources/layers are added to the Mapbox map. So we also listen for the next
            // map idle signal to ensure this internal flag is properly assigned.
            self.map.onMapIdle.observeNext { [weak self] _ in
                guard self != nil,
                      self?.map.isStyleLoaded == true,
                      self?.isStyleLoaded == false else { return }
                self?.isStyleLoaded = true
                Task { @MainActor in
                    closure()
                }
            }.store(in: &mapboxCancellables)
		}
	}
	
	/// Type-safe slot setter for a concrete Mapbox layer type.
	internal func setSlot<T: MapboxMaps.Layer>(_ slot: MapboxMaps.Slot, id: String, as type: T.Type) throws {
		try map.updateLayer(withId: id, type: type) { (layer: inout T) in
			layer.slot = slot
		}
	}

	/// Dispatches to a concrete typed setter based on `LayerType`.
	internal func setSlot(_ slot: MapboxMaps.Slot, forLayerId id: String, type: MapboxMaps.LayerType) throws {
		switch type {
		case .background:       
			try setSlot(slot, id: id, as: BackgroundLayer.self)
		case .fill:             
			try setSlot(slot, id: id, as: FillLayer.self)
		case .line:             
			try setSlot(slot, id: id, as: LineLayer.self)
		case .symbol:           
			try setSlot(slot, id: id, as: SymbolLayer.self)
		case .raster:          
			try setSlot(slot, id: id, as: RasterLayer.self)
		case .circle:           
			try setSlot(slot, id: id, as: CircleLayer.self)
		case .heatmap:          
			try setSlot(slot, id: id, as: HeatmapLayer.self)
		case .hillshade:        
			try setSlot(slot, id: id, as: HillshadeLayer.self)
		case .fillExtrusion:    
			try setSlot(slot, id: id, as: FillExtrusionLayer.self)
		case .sky:              
			try setSlot(slot, id: id, as: SkyLayer.self)
		case .model:            
			try setSlot(slot, id: id, as: ModelLayer.self)
		case .locationIndicator:
			try setSlot(slot, id: id, as: LocationIndicatorLayer.self)
		case .custom:
			try setSlot(slot, id: id, as: CustomLayer.self)
		default:
			break
		}
	}
}

extension MapboxMaps.MapboxMap: @retroactive ImageRegisteringMap {
	/// Registers an image for use in the style (e.g., `symbol` icons). Runs on the main actor.
	public func addImage(id: String, image: UIImage, sdf: Bool) throws {
		Task { @MainActor in
			try self.addImage(image, id: id, sdf: sdf)
		}
	}
}
