//
//  MapLibreMapController.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 9/12/25.
//

import Spatial
import OSLog
import Combine
import CoreLocation
import UIKit
import MapsGLCore
import MapsGLMaps
import MapLibre

public enum MapLibreMapControllerError: Error {
	case styleNotLoaded
}

/// A map controller implementation using the MapLibre SDK.
///
/// `MapLibreMapController` integrates MapsGL rendering layers with a `MapLibre.MLNMapView`
/// and provides lifecycle management for adding, removing, and reordering custom layers.
///
/// It supports custom renderer integration through `MapLibreLayerHost` and
/// `MLNCustomStyleLayer`, allowing MapsGL-compatible content to be rendered
/// atop a MapLibre-based map.
///
/// The controller ensures proper layer synchronization and defers operations
/// until the style is fully loaded to avoid premature access errors.
public final class MapLibreMapController : MapController<MapLibre.MLNMapView> {
	private struct LayerPlacement {
		let beforeId: String?
	}

	private var isStyleLoaded: Bool = false
	private var cancellables: Set<AnyCancellable> = []
	private var styleObservation: NSKeyValueObservation?
	private weak var tapGestureRecognizer: UITapGestureRecognizer?
	private var pendingStyleActions: [() -> Void] = []
	private var pendingLayersBySource: [String: [(layer: MapsGLMaps.VectorTileLayer, beforeId: String?, onLayerAdded: (() -> Void)? )]] = [:]
	private var pendingSourceSubscriptions: Set<String> = []
	private var placementByLayerId: [String: LayerPlacement] = [:]
	private var viewportHost: MapLibreViewportHost?
	private let mapDelegateProxy: MapLibreMapDelegateProxy
	private let styleLayerFactory = MapLibreStyleLayerFactory()
	private let geoJSONEncoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .millisecondsSince1970
		return encoder
	}()
	
	/// Creates a `MapboxMapController` from a `MapboxMaps.MapView`.
	/// - Parameters:
	///   - map: The map view instance.
	///   - account: The associated Xweather account.
	public convenience init(map: MapLibre.MLNMapView, account: XweatherAccount) {
		self.init(map: map, window: map.window, account: account)
	}
	
	/// Initializes the map controller with a Mapbox map, optional window, and account.
	/// - Parameters:
	///   - map: The underlying Mapbox map instance.
	///   - window: An optional window for context.
	///   - account: The associated Xweather account.
	public override init(map: MapLibre.MLNMapView, window: UIWindow? = nil, account: XweatherAccount) {
		self.mapDelegateProxy = MapLibreMapDelegateProxy(owner: nil, forwardedDelegate: map.delegate)
		super.init(map: map, window: window, account: account)
		
		self.mapDelegateProxy.owner = self
		map.delegate = mapDelegateProxy
		
		self.styleObservation = map.observe(\.style, options: [.initial, .new]) { [weak self] _, change in
			guard let self = self else { return }
			if (change.newValue ?? nil) != nil {
				self.handleStyleReady()
			} else {
				self.isStyleLoaded = false
			}
		}
		
		// Interactions
		installInteractionForwarding()
		
		self.isStyleLoaded = map.style != nil
		initialize()
	}
	
	// MARK: Coordinate Conversions
	
	override public func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
		map.convert(coordinate, toPointTo: map)
	}
	
	override public func coordinate(for point: CGPoint) -> CLLocationCoordinate2D {
		map.convert(point, toCoordinateFrom: map)
	}
	
	// MARK: MapController
	
	public override func initialize() {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			self.performBaseInitialize()
		}
	}
	
	override public func moveLayer(id: String, beforeId: String?) throws {
		try super.moveLayer(id: id, beforeId: beforeId)
		placementByLayerId[id] = .init(beforeId: beforeId)
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self, let style = self.map.style else { return }
			guard let targetLayer = style.layer(withIdentifier: id) else { return }
			style.removeLayer(targetLayer)
			self.insertLayer(targetLayer, beforeId: beforeId, style: style)
			self.moveFillStrokeLayerIfNeeded(for: id, above: targetLayer, style: style)
		}
	}
	
	// MARK: Adding/Removing MapsGL Resources
	
	public override func addToMap(source: some DataSource, onSourceAdded: (() -> Void)? = nil) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			Task { @MainActor in
				guard let style = self.map.style else { return }
				guard style.source(withIdentifier: source.id) == nil else { return }
				
				switch source {
				case let vectorSource as VectorTileSource:
					let adapter = MapLibreVectorSourceAdapter(source: vectorSource)
					let customSource = await adapter.makeSource()
					vectorSource.setInvalidateFunction(adapter.invalidate)
					style.addSource(customSource)
					onSourceAdded?()
				case let geoSource as GeoJSONSource:
					guard let shapeSource = self.makeShapeSource(from: geoSource) else { return }
					style.addSource(shapeSource)
					onSourceAdded?()
				default:
					break
				}
			}
		}
	}
	
	public override func removeFromMap(source: any DataSource) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self, let style = self.map.style else { return }
			guard let styleSource = style.source(withIdentifier: source.id) else { return }
			style.removeSource(styleSource)
		}
	}
	
	public override func addToMap(layer: any MapsGLLayer, beforeId: String?, onLayerAdded: (() -> Void)?) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			guard let style = self.map.style, style.layer(withIdentifier: layer.id) == nil else { return }
			self.placementByLayerId[layer.id] = .init(beforeId: beforeId)
			
			do {
				switch layer {
				case let vectorLayer as MapsGLMaps.VectorTileLayer:
					self.addMapsGLVectorLayer(layer: vectorLayer, beforeId: beforeId, onLayerAdded: onLayerAdded)
				case let metalLayer as any MapsGLMetalLayer:
					try self.addMapsGLMetalLayer(layer: metalLayer, beforeId: beforeId)
					onLayerAdded?()
				default:
					break
				}
			} catch {
				Logger.map.fault("Failed to add layer to map: \(error.localizedDescription)")
			}
		}
	}
	
	public override func removeFromMap(layer: any MapsGLLayer) {
		if layer is any MapsGLMetalLayer {
			try? self.removeLayerHost(id: layer.id)
		}
		viewportHost?.unregister(layer: layer)
		placementByLayerId.removeValue(forKey: layer.id)
		
		let removeAction: () -> Void = { [weak self] in
			guard let self = self else { return }
			self.removePendingLayer(withId: layer.id)
			if let style = self.map.style {
				if let styleLayer = style.layer(withIdentifier: layer.id) {
					style.removeLayer(styleLayer)
				}
				self.removeFillStrokeLayerIfNeeded(for: layer.id, style: style)
			}
			
			if let vectorLayer = layer as? MapsGLMaps.VectorTileLayer {
				vectorLayer.platformLayer = nil
			}
			self.removeViewportSyncLayerIfNeeded()
		}
		
		if isStyleLoaded, map.style != nil {
			removeAction()
		} else {
			pendingStyleActions.append(removeAction)
		}
	}
	
	public override func didRequestRedraw() {
		map.triggerRepaint()
		map.setNeedsDisplay()
	}

	public override func beforeIdForMaskLayers() -> String? {
		guard let style = map.style, style.layer(withIdentifier: "building") != nil else {
			return nil
		}
		return "building"
	}
	
	private func performBaseInitialize() {
		super.initialize()
	}
	
	deinit {
		if map.delegate === mapDelegateProxy {
			map.delegate = mapDelegateProxy.forwardedDelegate
		}
		if let tapGestureRecognizer {
			map.removeGestureRecognizer(tapGestureRecognizer)
		}
	}
	
	// MARK: Private helpers
	
	private func makeShapeSource(from source: GeoJSONSource) -> MapLibre.MLNShapeSource? {
		if let data = source.data, let encoded = try? geoJSONEncoder.encode(data),
		   let shape = try? MapLibre.MLNShape(data: encoded, encoding: String.Encoding.utf8.rawValue) {
			return MapLibre.MLNShapeSource(identifier: source.id, shape: shape, options: nil)
		} else if let url = source.makeDataURL() {
			return MapLibre.MLNShapeSource(identifier: source.id, url: url, options: nil)
		}
		return nil
	}
	
	private func addMapsGLMetalLayer(layer: some MapsGLMetalLayer, beforeId: String?) throws {
		guard let style = map.style else { return }
		if containsLayerHost(forId: layer.id) {
			guard style.layer(withIdentifier: layer.id) == nil else { return }
			try removeLayerHost(id: layer.id)
		}
		let customLayer = try MapLibreMapsGLLayer(map: self.map, layer: layer)
		try addLayerHost(customLayer.hostLayer)
		insertLayer(customLayer, beforeId: beforeId, style: style)
	}
	
	private func addMapsGLVectorLayer(layer: MapsGLMaps.VectorTileLayer, beforeId: String?, onLayerAdded: (() -> Void)? = nil) {
		guard let style = map.style else { return }
		installViewportSyncLayerIfNeeded(style: style)
		viewportHost?.register(layer: layer)

		guard let source = style.source(withIdentifier: layer.source.id) else {
			insertPendingVectorLayerPlaceholder(for: layer, beforeId: beforeId, style: style)
			queueVectorLayer(layer, beforeId: beforeId, onLayerAdded: onLayerAdded)
			return
		}
		
		var styleJSON = layer.paint.asStyleJSON(id: layer.id, source: layer.source.id, sourceLayer: layer.sourceLayer)
		styleJSON.filter = layer.filter
		layer.featureQuery = self
		
		guard let styleLayer = styleLayerFactory.makeStyleLayer(from: styleJSON, source: source) else { return }
		
		if let existingLayer = style.layer(withIdentifier: layer.id) {
			style.removeLayer(existingLayer)
		}
		removeFillStrokeLayerIfNeeded(for: layer.id, style: style)
		
		insertLayer(styleLayer, beforeId: beforeId, style: style)
		insertFillStrokeLayerIfNeeded(from: styleJSON, source: source, above: styleLayer, style: style)
		if let platformLayer = styleLayer as? any PlatformStyleLayer {
			layer.platformLayer = platformLayer
		}
		onLayerAdded?()
	}

	// MARK: Viewport Sync

	private func installViewportSyncLayerIfNeeded(style: MapLibre.MLNStyle) {
		let host: MapLibreViewportHost
		if let existingHost = viewportHost {
			host = existingHost
		} else {
			let newHost = MapLibreViewportHost(map: map)
			viewportHost = newHost
			host = newHost
		}

		guard style.layer(withIdentifier: host.id) == nil else { return }
		let syncLayer = MapLibreViewportSyncLayer(host: host)
		style.addLayer(syncLayer)
	}

	private func removeViewportSyncLayerIfNeeded() {
		guard let host = viewportHost else { return }
		if host.hasObservingLayers {
			return
		}
		if let style = map.style, let syncLayer = style.layer(withIdentifier: host.id) {
			style.removeLayer(syncLayer)
		}
		viewportHost = nil
	}
	
	private func insertLayer(_ layer: MapLibre.MLNStyleLayer, beforeId: String?, style: MapLibre.MLNStyle) {
		if let beforeId, let sibling = style.layer(withIdentifier: beforeId) {
			style.insertLayer(layer, below: sibling)
		} else {
			style.addLayer(layer)
		}
	}

	private func insertLayer(_ layer: MapLibre.MLNStyleLayer, above sibling: MapLibre.MLNStyleLayer, style: MapLibre.MLNStyle) {
		style.insertLayer(layer, above: sibling)
	}

	private func removeFillStrokeLayerIfNeeded(for layerID: String, style: MapLibre.MLNStyle) {
		let fillStrokeLayerID = styleLayerFactory.fillStrokeLayerID(for: layerID)
		if let fillStrokeLayer = style.layer(withIdentifier: fillStrokeLayerID) {
			style.removeLayer(fillStrokeLayer)
		}
	}

	private func moveFillStrokeLayerIfNeeded(for layerID: String, above fillLayer: MapLibre.MLNStyleLayer, style: MapLibre.MLNStyle) {
		let fillStrokeLayerID = styleLayerFactory.fillStrokeLayerID(for: layerID)
		if let fillStrokeLayer = style.layer(withIdentifier: fillStrokeLayerID) {
			style.removeLayer(fillStrokeLayer)
			style.insertLayer(fillStrokeLayer, above: fillLayer)
		}
	}

	private func insertFillStrokeLayerIfNeeded(
		from styleJSON: StyleJSON,
		source: MapLibre.MLNSource,
		above fillLayer: MapLibre.MLNStyleLayer,
		style: MapLibre.MLNStyle
	) {
		// MapLibre fill outline styling does not reliably match the Mapbox behavior we support,
		// so we render polygon outlines with a separate line layer positioned above the fill.
		guard let fillStrokeLayer = styleLayerFactory.makeFillStrokeLayer(from: styleJSON, source: source) else { return }
		insertLayer(fillStrokeLayer, above: fillLayer, style: style)
	}
	
	private func queueVectorLayer(_ layer: MapsGLMaps.VectorTileLayer, beforeId: String?, onLayerAdded: (() -> Void)? = nil) {
		let sourceId = layer.source.id
		var pending = pendingLayersBySource[sourceId] ?? []
		pending.append((layer, beforeId, onLayerAdded))
		pendingLayersBySource[sourceId] = pending
		
		if pendingSourceSubscriptions.contains(sourceId) == false {
			pendingSourceSubscriptions.insert(sourceId)
			onSourceAdded.publisher
				.filter { $0 == sourceId }
				.first()
				.sink { [weak self] _ in
					guard let self else { return }
					self.pendingSourceSubscriptions.remove(sourceId)
					self.flushPendingLayers(for: sourceId)
				}
				.store(in: &cancellables)
		}
	}
	
	private func flushPendingLayers(for sourceId: String) {
		guard let pending = pendingLayersBySource[sourceId] else { return }
		pendingLayersBySource[sourceId] = nil
		for entry in pending {
			addMapsGLVectorLayer(layer: entry.layer, beforeId: entry.beforeId, onLayerAdded: entry.onLayerAdded)
		}
	}
	
	private func removePendingLayer(withId id: String) {
		for (sourceId, entries) in pendingLayersBySource {
			let remaining = entries.filter { $0.layer.id != id }
			if remaining.isEmpty {
				pendingLayersBySource.removeValue(forKey: sourceId)
			} else {
				pendingLayersBySource[sourceId] = remaining
			}
		}
	}
	
	private func handleStyleReady() {
		isStyleLoaded = true
		updateManagedLayersForStyle()
		let actions = pendingStyleActions
		pendingStyleActions.removeAll()
		for action in actions {
			action()
		}
	}
	
	private func doEnsuringStyleLoaded(_ action: @escaping () -> Void) {
		if isStyleLoaded, map.style != nil {
			Task { @MainActor in
				action()
			}
		} else {
			pendingStyleActions.append { [weak self] in
				guard self != nil else { return }
				Task { @MainActor in
					action()
				}
			}
		}
	}

	private func updateManagedLayersForStyle() {
		updateMaskLayersForMap()
		for source in sources {
			addToMap(source: source, onSourceAdded: nil)
		}
		for layer in layers {
			let beforeId = placementByLayerId[layer.id]?.beforeId
			addToMap(layer: layer, beforeId: beforeId, onLayerAdded: nil)
		}
	}

	private func insertPendingVectorLayerPlaceholder(
		for layer: MapsGLMaps.VectorTileLayer,
		beforeId: String?,
		style: MapLibre.MLNStyle
	) {
		guard style.layer(withIdentifier: layer.id) == nil else { return }
		let placeholder = MLNBackgroundStyleLayer(identifier: layer.id)
		placeholder.backgroundOpacity = NSExpression(forConstantValue: NSNumber(value: 0.0))
		#if canImport(UIKit)
		placeholder.backgroundColor = NSExpression(forConstantValue: UIColor.clear)
		#endif
		insertLayer(placeholder, beforeId: beforeId, style: style)
	}
	
	// MARK: Interactions
	
	private func installInteractionForwarding() {
		let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
		tapGestureRecognizer.cancelsTouchesInView = false
		map.addGestureRecognizer(tapGestureRecognizer)
		self.tapGestureRecognizer = tapGestureRecognizer
	}
	
	fileprivate func handleMapMoved() {
		forwardMapMove()
	}
	
	fileprivate func handleMapMoveEnded() {
		forwardMapMoveEnd()
	}
	
	@objc
	private func handleMapTap(_ sender: UITapGestureRecognizer) {
		guard sender.state == .ended else { return }
		let point = sender.location(in: map)
		let coordinate = map.convert(point, toCoordinateFrom: map)
		forwardMapTap(to: point, coordinate: coordinate)
	}
}

// MARK: Feature Querying

extension MapLibreMapController: RenderedFeatureQuerying {
	
	@MainActor
	public func queryFeatures(in geometry: QueryGeometry, layerIds: [String]?) async throws -> [QueriedFeature] {
		let styleLayerIdentifiers = layerIds.map(Set.init)
		let features: [any MLNFeature]
		
		switch geometry {
		case .coordinate(let coordinate):
			let point = map.convert(coordinate, toPointTo: map)
			features = map.visibleFeatures(at: point, styleLayerIdentifiers: styleLayerIdentifiers, predicate: nil)
		case .point(let point):
			features = map.visibleFeatures(at: point, styleLayerIdentifiers: styleLayerIdentifiers, predicate: nil)
		case .rect(let rect):
			features = map.visibleFeatures(in: rect, styleLayerIdentifiers: styleLayerIdentifiers, predicate: nil)
		@unknown default:
			features = []
		}
		
		let context = featureQueryContext(layerIds: layerIds)
		return features.map { feature in
			let geoJSON = feature.geoJSONDictionary()
			let properties = (geoJSON["properties"] as? [String: Any]) ?? feature.attributes
			let featureId = stringValue(feature.identifier) ?? stringValue(geoJSON["id"])
			let source = stringValue(geoJSON["source"]) ??
				stringValue(feature.attributes["source"]) ??
				context.source ??
				"unknown"
			let sourceLayer = stringValue(geoJSON["sourceLayer"]) ??
				stringValue(feature.attributes["sourceLayer"]) ??
			context.sourceLayer
			
			return QueriedFeature(
				id: featureId,
				source: source,
				sourceLayer: sourceLayer,
				properties: properties
			)
		}
	}
	
	private struct FeatureQueryContext {
		var source: String?
		var sourceLayer: String?
	}
	
	private func featureQueryContext(layerIds: [String]?) -> FeatureQueryContext {
		guard let style = map.style,
			  let layerIds,
			  !layerIds.isEmpty else {
			return .init()
		}
		
		let styleLayers = layerIds.compactMap { style.layer(withIdentifier: $0) }
		let sources = Set(styleLayers.compactMap { ($0 as? MLNForegroundStyleLayer)?.sourceIdentifier })
		let sourceLayers = Set(styleLayers.compactMap { ($0 as? MLNVectorStyleLayer)?.sourceLayerIdentifier })
		
		return FeatureQueryContext(
			source: sources.count == 1 ? sources.first : nil,
			sourceLayer: sourceLayers.count == 1 ? sourceLayers.first : nil
		)
	}
	
	private func stringValue(_ value: Any?) -> String? {
		switch value {
		case let string as String:
			return string
		case let number as NSNumber:
			return number.stringValue
		default:
			return nil
		}
	}
}


private final class MapLibreMapDelegateProxy: NSObject, MLNMapViewDelegate {
	weak var owner: MapLibreMapController?
	weak var forwardedDelegate: MLNMapViewDelegate?
	
	init(owner: MapLibreMapController?, forwardedDelegate: MLNMapViewDelegate?) {
		self.owner = owner
		self.forwardedDelegate = forwardedDelegate
	}

	override func responds(to aSelector: Selector!) -> Bool {
		super.responds(to: aSelector) || (forwardedDelegate?.responds(to: aSelector) ?? false)
	}

	override func forwardingTarget(for aSelector: Selector!) -> Any? {
		if forwardedDelegate?.responds(to: aSelector) == true {
			return forwardedDelegate
		}
		return super.forwardingTarget(for: aSelector)
	}
	
	func mapView(_ mapView: MLNMapView, regionIsChangingWith reason: MLNCameraChangeReason) {
		owner?.handleMapMoved()
		forwardedDelegate?.mapView?(mapView, regionIsChangingWith: reason)
	}
	
	func mapView(_ mapView: MLNMapView, regionDidChangeWith reason: MLNCameraChangeReason, animated: Bool) {
		owner?.handleMapMoveEnded()
		forwardedDelegate?.mapView?(mapView, regionDidChangeWith: reason, animated: animated)
	}
}

extension MapLibre.MLNMapView: ImageRegisteringMap {
	public func addImage(id: String, image: UIImage, sdf: Bool) throws {
		guard let style else {
			throw MapLibreMapControllerError.styleNotLoaded
		}
		let resolvedImage = sdf ? image.withRenderingMode(.alwaysTemplate) : image
		style.setImage(resolvedImage, forName: id)
	}
}
