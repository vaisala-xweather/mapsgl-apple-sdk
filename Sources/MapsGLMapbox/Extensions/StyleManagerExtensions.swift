//
//  StyleManagerExtensions.swift
//  
//
//  Created by Slipp Douglas Thompson on 3/1/24.
//

import MapboxMaps

extension MapboxMaps.StyleManager
{
	/// Find the first layer which has an `id` matching the given `Regex`, and is of the given `LayerType`.
	public func firstLayer(matching regex: Regex<Substring>, type: MapboxMaps.LayerType = .line) -> MapboxMaps.LayerInfo? {
		self.allLayerIdentifiers.first { candidateLayer in
			candidateLayer.type == type && candidateLayer.id.contains(regex)
		}
	}
	
	/// Find the last layer which has an `id` matching the given `Regex`, and is of the given `LayerType`.
	public func lastLayer(matching regex: Regex<Substring>, type: MapboxMaps.LayerType = .line) -> MapboxMaps.LayerInfo? {
		self.allLayerIdentifiers.last { candidateLayer in
			candidateLayer.type == type && candidateLayer.id.contains(regex)
		}
	}
}
