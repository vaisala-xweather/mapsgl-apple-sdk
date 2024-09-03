//
//  MapboxLayerHost.swift
//  
//
//  Created by Nicholas Shipes on 10/18/23.
//

import Metal
import MapsGLCore
import MapsGLMaps
import MapsGLRenderer
import MapboxMaps



final class MapboxLayerHost<Layer> : LayerHost<Layer>, MapboxMaps.CustomLayerHost
	where Layer : MapLayer
{
	var map: MapboxMap
	
	init(map: MapboxMap, layer: Layer) throws {
		self.map = map
		
		try super.init(layer: layer)
	}
	
	// MARK: Render Loop
	
	func renderingWillStart(_ metalDevice: MTLDevice, colorPixelFormat colorPixelFormatRawValue: UInt, depthStencilPixelFormat depthStencilPixelFormatRawValue: UInt)
	{
		super.beginRendering(
			metalDevice: metalDevice,
			colorPixelFormat: MTLPixelFormat(rawValue: colorPixelFormatRawValue)!,
			depthStencilPixelFormat: MTLPixelFormat(rawValue: depthStencilPixelFormatRawValue)!
		)
	}
	
	func prerender(_ parameters: MapboxMaps.CustomLayerRenderParameters, mtlCommandBuffer: any MTLCommandBuffer) -> MapboxMaps.CustomLayerRenderConfiguration
	{
		self.layer.viewport.updateFrom(mapboxParameters: parameters, mapboxMap: self.map)
		
		super.prerender(
			mtlCommandBuffer: mtlCommandBuffer,
			renderTargetSize: .init(width: parameters.width, height: parameters.height)
		)
		
		return .init()
	}
	
	func render(_ parameters: MapboxMaps.CustomLayerRenderParameters, mtlCommandBuffer: any MTLCommandBuffer, mtlRenderPassDescriptor: MTLRenderPassDescriptor)
	{
		super.render(
			mtlCommandBuffer: mtlCommandBuffer, mtlRenderPassDescriptor: mtlRenderPassDescriptor,
			renderTargetSize: .init(width: parameters.width, height: parameters.height)
		)
	}
	
	func renderingWillEnd() {
		super.finishRendering()
	}
}
