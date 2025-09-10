//
//  MapboxPlacementResolver.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 9/10/25.
//

import MapboxMaps

/// A namespace for helper methods that compute and apply layer placement.
internal enum PlacementResolver {
	/// Builds a `Placement` for a prospective style layer by merging provider output and an optional `beforeId` hint.
	///
	/// Precedence:
	/// 1. If `provider` yields a placement, start from that value.
	/// 2. If `beforeId` is provided, it **overrides** the position with `.below(beforeId)`.
	///
	/// - Parameters:
	///   - layer: The (prospective) style layer to place. This is used for provider context only.
	///   - controller: The `MapboxMapController` whose `map` is used when the provider needs context.
	///   - provider: Optional provider that can decide placement based on the layer and the map.
	///   - beforeId: Optional layer id. If provided, the resulting placement’s position is set to `.below(beforeId)`.
	/// - Returns: A `MapboxMapController.Placement` that can later be resolved against the current style.
	static func make(for layer: MapboxMaps.Layer, in controller: MapboxMapController, provider: MapboxLayerPlacementProviding?, beforeId: String?) -> MapboxMapController.Placement {
		var placement = MapboxMapController.Placement(position: .default, slot: nil)
		if let layerPlacement = provider?.placement(for: layer, on: controller.map) {
			placement = layerPlacement
		}
		if let beforeId = beforeId {
			placement.position = .below(beforeId)
		}		
		return placement
	}
	
	/// Applies a previously computed placement to an existing style layer.
	///
	/// This resolves the placement against the current style, then:
	/// - Sets the layer’s `slot` if non-nil.
	/// - Moves the layer if the resolved position is not `.default`.
	///
	/// - Parameters:
	///   - placement: The placement to apply.
	///   - layer: The **existing** style layer (by id/type) to mutate.
	///   - controller: The controller whose `map` is mutated.
	/// - Throws: Any errors thrown by Mapbox when updating a typed layer or moving the layer.
	static func apply(_ placement: MapboxMapController.Placement, to layer: MapboxMaps.Layer, in controller: MapboxMapController) throws {
		let resolved = placement.resolved(for: controller.map)
		
		if let slot = resolved.slot {
			try controller.setSlot(slot, forLayerId: layer.id, type: layer.type)
		}
		if resolved.position != .default {
			try controller.map.moveLayer(withId: layer.id, to: resolved.position)
		}
	}
}
