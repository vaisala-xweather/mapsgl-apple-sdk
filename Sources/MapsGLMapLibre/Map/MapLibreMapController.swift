//
//  MapLibreMapController.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 9/12/25.
//

import Spatial
import Foundation
import OSLog
import Combine
import CoreLocation
import UIKit
import MapsGLCore
import MapsGLMaps
import MapLibre

private func runSynchronouslyOnMainThread(_ body: () -> Void) {
	if Thread.isMainThread {
		body()
	} else {
		DispatchQueue.main.sync {
			body()
		}
	}
}

/// Errors thrown by `MapLibreMapController`.
public enum MapLibreMapControllerError: Error {
	/// The requested operation requires a loaded style.
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
	private var tapGestureTarget: MapLibreTapGestureTarget?
	private var pendingStyleActions: [() -> Void] = []
	private var placementByLayerId: [String: LayerPlacement] = [:]
	private let mapDelegateProxy: MapLibreMapDelegateProxy
	
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

		// Metal-hosted layers are backed by a custom style layer (`MLNCustomStyleLayer`)
		// plus a layer host. Re-inserting that custom style-layer object directly leaves
		// the custom layer in a state that breaks a later re-add of another such layer (a
		// removed-then-re-enabled data-query text layer fails to re-appear). Reposition
		// these the same way they were first inserted — remove and re-add through the
		// bridge, which rebuilds the custom layer cleanly.
		if let layer = getLayer(id: id), layer is any MapsGLMetalLayer {
			removeFromMap(layer: layer)
			addToMap(layer: layer, beforeId: beforeId) { [weak self] in
				self?.invalidateLayerOrder()
			}
			return
		}

		placementByLayerId[id] = .init(beforeId: beforeId)
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self, let style = self.map.style else { return }
			guard let targetLayer = style.layer(withIdentifier: id) else { return }
			style.removeLayer(targetLayer)
			self.insertLayer(targetLayer, beforeId: beforeId, style: style)
			self.invalidateLayerOrder()
		}
	}

	/// The MapLibre style's layer identifiers in draw order, bottom-most first.
	public override func styleLayerOrder() -> [String] {
		map.style?.layers.map(\.identifier) ?? []
	}
	
	// MARK: Adding/Removing MapsGL Resources
	
	/// MapsGL sources are read by MapsGL's own renderers, never by the MapLibre
	/// style, so there is nothing to bridge. Reports completion so callers
	/// awaiting a source add still proceed.
	public override func addToMap(source: some DataSource, onSourceAdded: (() -> Void)? = nil) {
		doEnsuringStyleLoaded { onSourceAdded?() }
	}
	
	/// No-op counterpart to ``addToMap(source:onSourceAdded:)`` — MapsGL sources
	/// are never added to the MapLibre style.
	public override func removeFromMap(source: any DataSource) {}
	
	public override func addToMap(layer: any MapsGLLayer, beforeId: String?, onLayerAdded: (() -> Void)?) {
		doEnsuringStyleLoaded { [weak self] in
			guard let self = self else { return }
			guard let style = self.map.style else { return }
			guard style.layer(withIdentifier: layer.id) == nil else { return }
			self.placementByLayerId[layer.id] = .init(beforeId: beforeId)
			let handleLayerAdded = { [weak self] in
				guard let self = self else { return }
				if let beforeId, beforeId.hasPrefix("mask::") {
					self.ensureLayer(beforeId, isAbove: layer.id, in: style)
				}
				onLayerAdded?()
			}
			
			do {
				if let metalLayer = layer as? any MapsGLMetalLayer {
					try self.addMapsGLMetalLayer(layer: metalLayer, beforeId: beforeId)
					handleLayerAdded()
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
		placementByLayerId.removeValue(forKey: layer.id)
		
		let removeAction: () -> Void = { [weak self] in
			guard let self = self else { return }
			if let style = self.map.style, let styleLayer = style.layer(withIdentifier: layer.id) {
				style.removeLayer(styleLayer)
			}
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
		let map = self.map
		let mapDelegateProxy = self.mapDelegateProxy
		let tapGestureRecognizer = self.tapGestureRecognizer
		runSynchronouslyOnMainThread {
			if map.delegate === mapDelegateProxy {
				map.delegate = mapDelegateProxy.forwardedDelegate
			}
			if let tapGestureRecognizer {
				map.removeGestureRecognizer(tapGestureRecognizer)
			}
		}
	}
	
	// MARK: Private helpers
	
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
	
	// MARK: Viewport Sync

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

	private func handleStyleReady() {
		Task { @MainActor in
			self.isStyleLoaded = true
			await self.updateManagedLayersForStyle()
			let actions = self.pendingStyleActions
			self.pendingStyleActions.removeAll()
			for action in actions {
				action()
			}
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

	@MainActor
	private func updateManagedLayersForStyle() async {
		let orderedLayers = managedLayersInPlacementOrder()
		for layer in orderedLayers {
			let beforeId = placementByLayerId[layer.id]?.beforeId
			guard let style = map.style else { continue }
			guard style.layer(withIdentifier: layer.id) == nil else { continue }
			do {
				if let metalLayer = layer as? any MapsGLMetalLayer {
					try addMapsGLMetalLayer(layer: metalLayer, beforeId: beforeId)
				}
				if let beforeId, beforeId.hasPrefix("mask::") {
					ensureLayer(beforeId, isAbove: layer.id, in: style)
				}
			} catch {
				Logger.map.fault("Failed to restore layer during style reload: \(error.localizedDescription)")
			}
		}
	}

	private func managedLayersInPlacementOrder() -> [any MapsGLLayer] {
		let layersByID = Dictionary(uniqueKeysWithValues: layers.map { ($0.id, $0) })
		let managedLayerIDs = Set(layersByID.keys)
		var visited = Set<String>()
		var orderedIDs: [String] = []

		func visit(_ layerID: String) {
			guard visited.contains(layerID) == false else { return }
			visited.insert(layerID)
			if let beforeId = placementByLayerId[layerID]?.beforeId, managedLayerIDs.contains(beforeId) {
				visit(beforeId)
			}
			orderedIDs.append(layerID)
		}

		for layer in layers {
			visit(layer.id)
		}

		return orderedIDs.compactMap { layersByID[$0] }
	}

	private func ensureLayer(_ layerID: String, isAbove siblingID: String, in style: MapLibre.MLNStyle) {
		guard let layer = style.layer(withIdentifier: layerID),
			  let sibling = style.layer(withIdentifier: siblingID) else { return }
		style.removeLayer(layer)
		style.insertLayer(layer, above: sibling)
	}
	
	// MARK: Interactions
	
	private func installInteractionForwarding() {
		let tapGestureTarget = MapLibreTapGestureTarget(owner: self)
		let tapGestureRecognizer = UITapGestureRecognizer(target: tapGestureTarget, action: #selector(MapLibreTapGestureTarget.handleMapTap(_:)))
		tapGestureRecognizer.cancelsTouchesInView = false
		map.addGestureRecognizer(tapGestureRecognizer)
		self.tapGestureTarget = tapGestureTarget
		self.tapGestureRecognizer = tapGestureRecognizer
	}
	
	fileprivate func handleMapMoved() {
		forwardMapMove()
	}
	
	fileprivate func handleMapMoveEnded() {
		forwardMapMoveEnd()
	}
	
	@objc
	fileprivate func handleMapTap(_ sender: UITapGestureRecognizer) {
		guard sender.state == .ended else { return }
		let point = sender.location(in: map)
		let coordinate = map.convert(point, toCoordinateFrom: map)
		forwardMapTap(to: point, coordinate: coordinate)
	}
}

// MARK: Feature Querying

extension MapLibreMapController: RenderedFeatureQuerying {
	
	@MainActor
	/// Queries rendered features visible within the provided geometry.
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

private final class MapLibreTapGestureTarget: NSObject {
	weak var owner: MapLibreMapController?

	init(owner: MapLibreMapController?) {
		self.owner = owner
	}

	@objc
	func handleMapTap(_ sender: UITapGestureRecognizer) {
		owner?.handleMapTap(sender)
	}
}

extension MapLibre.MLNMapView: ImageRegisteringMap {
	/// Registers an image with the current style.
	public func addImage(id: String, image: UIImage, sdf: Bool) throws {
		guard let style else {
			throw MapLibreMapControllerError.styleNotLoaded
		}
		let resolvedImage = sdf ? image.withRenderingMode(.alwaysTemplate) : image
		style.setImage(resolvedImage, forName: id)
	}
}
