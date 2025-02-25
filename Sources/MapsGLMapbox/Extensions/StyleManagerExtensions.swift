//
//  StyleManagerExtensions.swift
//  
//
//  Created by Slipp Douglas Thompson on 3/1/24.
//

import MapboxMaps

public extension MapboxMaps.StyleManager {
    /// Find the first layer which has an `id` matching the given `Regex`, and is of the given `LayerType`.
    @available(iOS 16.0, *)
    func firstLayer(matching regex: Regex<Substring>, type: MapboxMaps.LayerType = .line) -> MapboxMaps.LayerInfo? {
        allLayerIdentifiers.first { candidateLayer in
            candidateLayer.type == type && candidateLayer.id.contains(regex)
        }
    }

    @available(iOS, deprecated: 16.0, message: "Use the version that takes a Regex<Substring> as parameter.")
    func firstLayer(matching pattern: String, type: LayerType = .line) -> LayerInfo? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        return allLayerIdentifiers.first { candidateLayer in
            candidateLayer.type == type && regex.firstMatch(in: candidateLayer.id, options: [], range: NSRange(location: 0, length: candidateLayer.id.utf16.count)) != nil
        }
    }

    /// Find the last layer which has an `id` matching the given `Regex`, and is of the given `LayerType`.
    @available(iOS 16.0, *)
    func lastLayer(matching regex: Regex<Substring>, type: MapboxMaps.LayerType = .line) -> MapboxMaps.LayerInfo? {
        allLayerIdentifiers.last { candidateLayer in
            candidateLayer.type == type && candidateLayer.id.contains(regex)
        }
    }

    @available(iOS, deprecated: 16.0, message: "Use the version that takes a Regex<Substring> as parameter.")
    func lastLayer(matching pattern: String, type: LayerType = .line) -> LayerInfo? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        return allLayerIdentifiers.last { candidateLayer in
            candidateLayer.type == type && regex.firstMatch(in: candidateLayer.id, options: [], range: NSRange(location: 0, length: candidateLayer.id.utf16.count)) != nil
        }
    }
}
