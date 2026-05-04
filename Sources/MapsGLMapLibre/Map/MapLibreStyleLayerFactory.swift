//
//  MapLibreStyleLayerFactory.swift
//  MapsGL
//
//  Created by Anthony Pardee on 2/18/26.
//

import Foundation
import MapsGLMaps
import MapLibre
#if canImport(UIKit)
import UIKit
#endif

struct MapLibreStyleLayerFactory {

	private static let fillStrokeLayerIDSuffix = "-stroke"
	
	func makeStyleLayer(from style: StyleJSON, source: MapLibre.MLNSource) -> MapLibre.MLNStyleLayer? {
		let layer: MapLibre.MLNStyleLayer?
		
		switch style.type {
		case .fill:
			let fillLayer = MapLibre.MLNFillStyleLayer(identifier: style.id, source: source)
			fillLayer.fillColor = makeExpression(style.fillColor)
			fillLayer.fillOpacity = makeExpression(style.fillOpacity)
			fillLayer.fillSortKey = makeExpression(style.fillSortKey)
			layer = fillLayer
		case .line:
			let lineLayer = MapLibre.MLNLineStyleLayer(identifier: style.id, source: source)
			lineLayer.lineColor = makeExpression(style.lineColor)
			lineLayer.lineOpacity = makeExpression(style.lineOpacity)
			lineLayer.lineWidth = makeExpression(style.lineWidth)
			lineLayer.lineCap = makeExpression(style.lineCap)
			lineLayer.lineJoin = makeExpression(style.lineJoin)
			layer = lineLayer
		case .circle:
			let circleLayer = MapLibre.MLNCircleStyleLayer(identifier: style.id, source: source)
			circleLayer.circleColor = makeExpression(style.circleColor)
			circleLayer.circleOpacity = makeExpression(style.circleOpacity)
			circleLayer.circleStrokeColor = makeExpression(style.circleStrokeColor)
			circleLayer.circleStrokeOpacity = makeExpression(style.circleStrokeOpacity)
			circleLayer.circleStrokeWidth = makeExpression(style.circleStrokeWidth)
			circleLayer.circleRadius = makeExpression(style.circleRadius)
			circleLayer.circleSortKey = makeExpression(style.circleSortKey)
			layer = circleLayer
		case .heatmap:
			let heatmapLayer = MapLibre.MLNHeatmapStyleLayer(identifier: style.id, source: source)
			heatmapLayer.heatmapColor = makeExpression(style.heatmapColor)
			heatmapLayer.heatmapIntensity = makeExpression(style.heatmapIntensity)
			heatmapLayer.heatmapOpacity = makeExpression(style.heatmapOpacity)
			heatmapLayer.heatmapRadius = makeScaledHeatmapRadiusExpression(style.heatmapRadius)
			heatmapLayer.heatmapWeight = makeExpression(style.heatmapWeight)
			layer = heatmapLayer
		case .symbol:
			let symbolLayer = MapLibre.MLNSymbolStyleLayer(identifier: style.id, source: source)
			symbolLayer.iconAllowsOverlap = makeExpression(style.iconAllowOverlap)
			symbolLayer.iconAnchor = makeExpression(style.iconAnchor)
			symbolLayer.iconColor = makeExpression(style.iconColor)
			symbolLayer.iconHaloBlur = makeExpression(style.iconHaloBlur)
			symbolLayer.iconHaloColor = makeExpression(style.iconHaloColor)
			symbolLayer.iconHaloWidth = makeExpression(style.iconHaloWidth)
			symbolLayer.iconImageName = makeExpression(style.iconImage)
			symbolLayer.iconOffset = makeOffsetExpression(style.iconOffset)
			symbolLayer.iconOpacity = makeExpression(style.iconOpacity)
			symbolLayer.iconPadding = makeEdgeInsetsExpression(style.iconPadding)
			symbolLayer.iconRotation = makeExpression(style.iconRotate)
			symbolLayer.iconScale = makeExpression(style.iconSize)
			
			symbolLayer.textAllowsOverlap = makeExpression(style.textAllowOverlap)
			symbolLayer.textAnchor = makeExpression(style.textAnchor)
			symbolLayer.text = makeExpression(style.textField)
			symbolLayer.textColor = makeExpression(style.textColor)
			symbolLayer.textHaloColor = makeExpression(style.textHaloColor)
			symbolLayer.textHaloBlur = makeExpression(style.textHaloBlur)
			symbolLayer.textHaloWidth = makeExpression(style.textHaloWidth)
			symbolLayer.textOpacity = makeExpression(style.textOpacity)
			symbolLayer.textJustification = makeExpression(style.textJustify)
			symbolLayer.textLetterSpacing = makeExpression(style.textLetterSpacing)
			symbolLayer.textLineHeight = makeExpression(style.textLineHeight)
			symbolLayer.maximumTextWidth = makeExpression(style.textMaxWidth)
			symbolLayer.textOffset = makeOffsetExpression(style.textOffset)
			symbolLayer.textPadding = makeExpression(style.textPadding)
			symbolLayer.textRotation = makeExpression(style.textRotate)
			symbolLayer.textFontSize = makeExpression(style.textSize)
			symbolLayer.textTransform = makeExpression(style.textTransform)
			layer = symbolLayer
		default:
			layer = nil
		}
		
		guard let layer else { return nil }
		configureVectorStyleLayer(layer, from: style)
		return layer
	}

	func makeFillStrokeLayer(from style: StyleJSON, source: MapLibre.MLNSource) -> MapLibre.MLNLineStyleLayer? {
		guard style.type == .fill else { return nil }
		let strokeLayer = MapLibre.MLNLineStyleLayer(identifier: fillStrokeLayerID(for: style.id), source: source)
		strokeLayer.lineColor = makeExpression(style.fillOutlineColor)
		// Closest observed line width scale to match the default Mapbox fill outline.
		strokeLayer.lineWidth = NSExpression(forConstantValue: NSNumber(value: 0.1))
		configureVectorStyleLayer(strokeLayer, from: style)
		return strokeLayer
	}

	func fillStrokeLayerID(for layerID: String) -> String {
		"\(layerID)\(Self.fillStrokeLayerIDSuffix)"
	}

	private func configureVectorStyleLayer(_ layer: MapLibre.MLNStyleLayer, from style: StyleJSON) {
		if let vectorStyleLayer = layer as? MapLibre.MLNVectorStyleLayer {
			vectorStyleLayer.sourceLayerIdentifier = style.sourceLayer
			vectorStyleLayer.predicate = predicate(from: style.filter)
		}
	}
	
	private func predicate(from expression: MapsGLMaps.Expression?) -> NSPredicate? {
		guard let expression else { return nil }
		return NSPredicate(mglJSONObject: expression.toJSONObject())
	}
	
	private func makeExpression<T>(_ value: StyleValue<T>?) -> NSExpression? {
		guard let value else { return nil }
		switch value {
		case .constant(let literal):
			return NSExpression(forConstantValue: convertConstantValue(literal))
		case .expression(let expression):
			return NSExpression(mglJSONObject: expression.toJSONObject())
		}
	}

	private func makeScaledHeatmapRadiusExpression(_ value: StyleValue<Double>?) -> NSExpression? {
		guard let value else { return nil }
#if canImport(UIKit)
		// MapLibre heatmap kernels render broader than Mapbox for the same style radius.
		// A sublinear adjustment best matches the observed Mapbox appearance.
		let compensation = sqrt(Double(UIScreen.main.scale))
		guard compensation > 0, compensation != 1 else {
			return makeExpression(value)
		}
		switch value {
		case .constant(let radius):
			return NSExpression(forConstantValue: NSNumber(value: radius / compensation))
		case .expression(let expression):
			return NSExpression(mglJSONObject: ["/", expression.toJSONObject(), compensation])
		}
#else
		return makeExpression(value)
#endif
	}

	private func makeEdgeInsetsExpression(_ value: StyleValue<Double>?) -> NSExpression? {
		guard let value else { return nil }
		switch value {
		case .constant(let inset):
#if canImport(UIKit)
			let edges = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
			return NSExpression(forConstantValue: NSValue(uiEdgeInsets: edges))
#else
			return NSExpression(forConstantValue: inset)
#endif
		case .expression(let expression):
			return NSExpression(mglJSONObject: expression.toJSONObject())
		}
	}

	private func makeOffsetExpression(_ value: StyleValue<AnchorOffset>?) -> NSExpression? {
		guard let value else { return nil }
		switch value {
		case .constant(let offset):
			return NSExpression(forConstantValue: NSValue(cgVector: CGVector(dx: offset.x, dy: offset.y)))
		case .expression(let expression):
			return NSExpression(mglJSONObject: wrapArrayLiterals(in: expression.toJSONObject()))
		}
	}

	private func wrapArrayLiterals(in value: Any) -> Any {
		switch value {
		case let array as [Any]:
			let wrapped = array.map { wrapArrayLiterals(in: $0) }
			if let head = wrapped.first as? String {
				// Expression arrays start with an operator string and must remain expressions.
				if head == "literal", wrapped.count == 2 {
					return wrapped
				}
				return wrapped
			}
			return ["literal", wrapped]
		case let dictionary as [String: Any]:
			return dictionary.mapValues { wrapArrayLiterals(in: $0) }
		default:
			return value
		}
	}
	
	private func convertConstantValue(_ value: Any) -> Any {
		switch value {
		case let anchor as Anchor:
			return anchor.rawValue
		case let offset as AnchorOffset:
			return NSValue(cgVector: CGVector(dx: offset.x, dy: offset.y))
		case let justification as TextJustification:
			return justification.rawValue
		case let transform as TextTransform:
			return transform.rawValue
		case let lineCap as StrokePaint.LineCap:
			return lineCap.rawValue
		case let lineJoin as StrokePaint.LineJoin:
			return lineJoin.rawValue
		case let boolValue as Bool:
			return boolValue
		case let number as NSNumber:
			return number
		case let doubleValue as Double:
			return NSNumber(value: doubleValue)
		case let cgFloat as CGFloat:
			return NSNumber(value: Double(cgFloat))
		case let intValue as Int:
			return NSNumber(value: intValue)
#if canImport(UIKit)
		case let color as UIColor:
			return color
#endif
		default:
			return value
		}
	}
}
