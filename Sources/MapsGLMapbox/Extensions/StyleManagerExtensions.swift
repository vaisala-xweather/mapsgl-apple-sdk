//
//  StyleManagerExtensions.swift
//  
//
//  Created by Slipp Douglas Thompson on 3/1/24.
//

import MapsGLMaps
import MapboxMaps
import UIKit

enum PropertyKind: Int {
	case undefined = 0
	case constant = 1
	case expression = 2
	case transition = 3
}

extension MapboxMaps.StyleManager {
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
	
	public func layerStyleColorValue(id: String, property: String) -> MapsGLMaps.StyleValue<UIColor>? {
		guard layerExists(withId: id) else { return nil }
		
		let propertyValue = layerProperty(for: id, property: property)
		
		// MBMStylePropertyValueKind: 0=undefined, 1=constant, 2=expression, 3=transition
		if let rawExpression = propertyValue.value as? [Any], propertyValue.kind == .expression {
			return StyleValue.expression(Expression(rawExpression))
		}
		
		return nil
	}
}
