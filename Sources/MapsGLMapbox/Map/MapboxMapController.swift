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
		
		self.map.onCameraChanged.observe { [weak self] _ in
			self?.forwardMapMove()
		}.store(in: &mapboxCancellables)
		
		self.map.onMapIdle.observe { [weak self] _ in
			self?.forwardMapMoveEnd()
		}
		.store(in: &mapboxCancellables)
		
		// Interactions
		self.map.addInteraction(TapInteraction { [weak self] context in
			self?.forwardMapTap(to: context.point, coordinate: context.coordinate)
			return false
		})
		
		self.isStyleLoaded = self.map.isStyleLoaded
		initialize()
	}
	
	// MARK: Coordinate Conversions
	
	override public func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
		return map.point(for: coordinate)
	}
	
	override public func coordinate(for point: CGPoint) -> CLLocationCoordinate2D {
		return map.coordinate(for: point)
	}
	
	// MARK: MapController
	
	/// Performs controller setup once the style is ready.
	///
	/// This calls `super.initialize()` within `doEnsuringStyleLoaded` to ensure that
	/// style-dependent work is deferred until the style has finished loading.
	public override func initialize() {		
		doEnsuringStyleLoaded { [weak self] in
			guard let self else { return }
			self.superInit()
		}
	}
	
	private func superInit() {
		// Pulled into a local function due to:
		// 'Using 'super' in a closure where 'self' is explicitly captured is not yet supported'
		super.initialize()
	}
	
	/// Moves a map layer beneath another layer by ID.
	/// - Parameters:
	///   - id: The id of the layer to move.
	///   - beforeId: If non-nil, the destination layer id to move **below**; otherwise `.default` is used.
	/// - Throws: Errors thrown by Mapbox style mutation.
	override public func moveLayer(id: String, beforeId: String?) throws {
		try super.moveLayer(id: id, beforeId: beforeId)
		guard map.layerExists(withId: id) else { return }

		// MapsGL Metal layers are bridged as persistent Mapbox `CustomLayer`s. Mapbox's
		// `moveLayer` on a persistent custom layer leaves the persistent custom-layer
		// registry in a state that breaks a later re-add of another such layer (a
		// removed-then-re-enabled data-query text layer fails to re-appear). Reposition
		// these the same way they were first inserted — remove and re-add through the
		// bridge — which is a clean insert and preserves the caller's placement (and
		// slot, in slotted styles).
		if let layer = getLayer(id: id), layer is any MapsGLMetalLayer {
			removeFromMap(layer: layer)
			addToMap(layer: layer, beforeId: beforeId) { [weak self] in
				self?.invalidateLayerOrder()
			}
			return
		}

		if let beforeId {
			try map.moveLayer(withId: id, to: .below(beforeId))
		} else {
			try map.moveLayer(withId: id, to: .default)
		}
		invalidateLayerOrder()
	}

	/// The Mapbox style's layer identifiers in draw order, bottom-most first.
	public override func styleLayerOrder() -> [String] {
		map.allLayerIdentifiers.map(\.id)
	}

	// MARK: Adding/Removing MapsGL Resources
	
	/// MapsGL sources are read by MapsGL's own renderers, never by the Mapbox
	/// style, so there is nothing to bridge. Reports completion so callers
	/// awaiting a source add still proceed.
	public override func addToMap(source: some DataSource, onSourceAdded: (() -> Void)? = nil) {
		doEnsuringStyleLoaded { onSourceAdded?() }
	}
	
	/// Adds a MapsGL layer to the Mapbox style, converting it to the appropriate Mapbox layer.
	/// - Parameters:
	///   - layer: The MapsGL layer.
	///   - beforeId: Optional id to place the layer **below**.
	public override func addToMap(layer: any MapsGLLayer, beforeId: String?, onLayerAdded: (() -> Void)? = nil) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			guard !self.map.layerExists(withId: layer.id) else { return }
			let handleLayerAdded = { [weak self] in
				onLayerAdded?()
			}
			do {
				if let metalLayer = layer as? any MapsGLMetalLayer {
					try addMapsGLMetalLayer(layer: metalLayer, beforeId: beforeId) {
						handleLayerAdded()
					}
				}
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error)")
			}
		}
	}
	
	/// No-op counterpart to ``addToMap(source:onSourceAdded:)`` — MapsGL sources
	/// are never added to the Mapbox style.
	public override func removeFromMap(source: any DataSource) {}
	
	/// Removes a previously added layer from the style and from the controller’s registry.
	/// - Parameter layer: The layer to remove.
	public override func removeFromMap(layer: any MapsGLLayer) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			do {
				// Remove the `MapboxMaps.CustomLayer` from the `MapboxMaps.MapboxMap`.
				if self.map.layerExists(withId: layer.id) {
					try self.map.removeLayer(withId: layer.id)
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
		// A new style brings its own layers, and the re-applied placements above move
		// MapsGL's within them.
		invalidateLayerOrder()
	}
	
	// MARK: MapsGL Layer Bridge
	
	/// Bridges a `MapsGLMetalLayer` into a `MapboxMaps.CustomLayer` and inserts it with resolved placement.
	private func addMapsGLMetalLayer(layer: some MapsGLMetalLayer, beforeId: String?, onLayerAdded: (() -> Void)? = nil) throws {
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
		onLayerAdded?()
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

// MARK: Feature Querying

extension MapboxMapController: RenderedFeatureQuerying {
	public func queryFeatures(in geometry: MapsGLMaps.QueryGeometry, layerIds: [String]?) async throws -> [MapsGLMaps.QueriedFeature] {
		let queryGeometry: RenderedQueryGeometryConvertible
		switch geometry {
		case .coordinate(let coordinate):
			queryGeometry = map.point(for: coordinate)
		case .point(let point):
			queryGeometry = point
		case .rect(let rect):
			queryGeometry = rect
		@unknown default:
			fatalError("Unknown geometry case")
		}
		
		let options = RenderedQueryOptions(layerIds: layerIds, filter: nil)
		let results = try await queryRenderedFeaturesAsync(with: queryGeometry, options: options)
		
		// Must convert each Mapbox queried feature result to a MapsGL `QueriedFeature`.
		return results.map { result in
			var json: [String: Any] = [:]
			var featureId: String? = nil
			var featureProperties: [String: Any] = [:]
			
			do {
				let jsonData = try JSONEncoder().encode(result.queriedFeature.feature)
				if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
					json = jsonObject
				}
			} catch {
				//
			}
			
			if let id = json["id"] as? String {
				featureId = id
			}
			if let data = json["properties"] as? [String: Any] {
				featureProperties = data
			}
			
			return MapsGLMaps.QueriedFeature(
				id: featureId,
				source: result.queriedFeature.source,
				sourceLayer: result.queriedFeature.sourceLayer,
				properties: featureProperties
			)
		}
	}
	
	@MainActor
	private func queryRenderedFeaturesAsync(
		with geometry: RenderedQueryGeometryConvertible,
		options: RenderedQueryOptions
	) async throws -> [QueriedRenderedFeature] {
		try await withCheckedThrowingContinuation { continuation in
			map.queryRenderedFeatures(with: geometry, options: options) { result in
				continuation.resume(with: result)
			}
		}
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

extension MapboxMaps.MapboxMap: ImageRegisteringMap {
	/// Registers an image for use in the style (e.g., `symbol` icons). Runs on the main actor.
	public func addImage(id: String, image: UIImage, sdf: Bool) throws {
		Task { @MainActor in
			try self.addImage(image, id: id, sdf: sdf)
		}
	}
}
