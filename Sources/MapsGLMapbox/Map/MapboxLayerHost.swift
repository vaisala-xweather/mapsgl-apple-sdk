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
import OSLog

/// A custom layer host that integrates a `MapsGLMetalLayer` with Mapbox’s `CustomLayerHost`.
///
/// This class bridges MapsGL rendering into the Mapbox rendering pipeline using Metal.
/// It implements the required `CustomLayerHost` methods to control rendering lifecycle,
/// including setup, prerendering, and final rendering steps.
public final class MapboxLayerHost<Layer> : LayerHost<Layer>, MapboxMaps.CustomLayerHost where Layer : MetalLayerProtocol {
	
	/// The Mapbox map associated with the custom layer.
	weak var map: MapboxMap?
	weak var mtlDevice: MTLDevice?
	
	/// Creates a new layer host bound to a Mapbox map and a MapsGL-compatible layer.
	/// - Parameters:
	///   - map: The Mapbox map to attach to.
	///   - layer: The MapsGL layer to manage.
	/// - Throws: An error if the superclass initialization fails.
	init(map: MapboxMap, layer: Layer) throws {
		self.map = map
		try super.init(layer: layer)
	}
	
	// MARK: Render Loop
	
	/// Called when rendering is about to start.
	/// Sets up the Metal device and pixel formats for the render loop.
	/// - Parameters:
	///   - metalDevice: The Metal device used for rendering.
	///   - colorPixelFormatRawValue: The raw value of the color pixel format.
	///   - depthStencilPixelFormatRawValue: The raw value of the depth-stencil pixel format.
	public func renderingWillStart(_ metalDevice: MTLDevice, colorPixelFormat colorPixelFormatRawValue: UInt, depthStencilPixelFormat depthStencilPixelFormatRawValue: UInt) {
		self.mtlDevice = metalDevice
		super.beginRendering(
			metalDevice: metalDevice,
			colorPixelFormat: MTLPixelFormat(rawValue: colorPixelFormatRawValue)!,
			depthStencilPixelFormat: MTLPixelFormat(rawValue: depthStencilPixelFormatRawValue)!
		)
	}
	
	/// Called before rendering to perform preparation work.
	/// Updates the viewport and prepares the rendering layer.
	/// - Parameters:
	///   - parameters: The render parameters provided by Mapbox.
	///   - mtlCommandBuffer: The Metal command buffer used for rendering.
	/// - Returns: A custom layer render configuration.
	public func prerender(_ parameters: MapboxMaps.CustomLayerRenderParameters, mtlCommandBuffer: any MTLCommandBuffer) -> MapboxMaps.CustomLayerRenderConfiguration {
		guard let map, let mtlDevice else { return .init() }
		
		self.layer.viewport.updateFrom(mapboxParameters: parameters, mapboxMap: map)
		do {
			let renderTargetSize = CGSize(width: parameters.width, height: parameters.height)
			let metalContext = try MetalRenderContext.create(mtlDevice: mtlDevice, commandBuffer: mtlCommandBuffer, renderPassDescriptor: nil, size: renderTargetSize)
			super.prerender(metalContext: metalContext)
		} catch {
			Logger.map.error("Failed to create MetalRenderContext: \(error)")
		}
		
		return .init()
	}
	
	/// Executes the final rendering commands for the layer.
	/// - Parameters:
	///   - parameters: The render parameters provided by Mapbox.
	///   - mtlCommandBuffer: The Metal command buffer.
	///   - mtlRenderPassDescriptor: The Metal render pass descriptor.
	public func render(_ parameters: MapboxMaps.CustomLayerRenderParameters, mtlCommandBuffer: any MTLCommandBuffer, mtlRenderPassDescriptor: MTLRenderPassDescriptor) {
		guard let mtlDevice else { return }
		do {
			let renderTargetSize = CGSize(width: parameters.width, height: parameters.height)
			let metalContext = try MetalRenderContext.create(mtlDevice: mtlDevice, commandBuffer: mtlCommandBuffer, renderPassDescriptor: mtlRenderPassDescriptor, size: renderTargetSize)
			super.render(metalContext: metalContext)
		} catch {
			Logger.map.error("Failed to create MetalRenderContext: \(error)")
		}
	}
	
	/// Called when rendering is finished.
	/// Performs cleanup of rendering resources.
	public func renderingWillEnd() {
		super.finishRendering()
	}
}

extension FillLayer: PlatformStyleLayer {}
extension LineLayer: PlatformStyleLayer {}
extension CircleLayer: PlatformStyleLayer {}
extension SymbolLayer: PlatformStyleLayer {}
extension HeatmapLayer: PlatformStyleLayer {}

/// A non-rendering CustomLayerHost that forwards Mapbox render parameters to a client.
internal final class MapboxViewportHost: NSObject, MapboxMaps.CustomLayerHost {
	internal let id: String = "mapsgl-viewport-host"
	weak var map: MapboxMap?
	private var observingLayers: [any LayerProtocol] = []

	init(map: MapboxMaps.MapboxMap) {
		self.map = map
	}
	
	func register(layer: any LayerProtocol) {
		observingLayers.append(layer)
	}
	
	func unregister(layer: any LayerProtocol) {
		observingLayers.removeAll { $0 as AnyObject === layer as AnyObject }
	}

	// MARK: - CustomLayerHost

	func renderingWillStart(_ metalDevice: MTLDevice,
							colorPixelFormat: UInt,
							depthStencilPixelFormat: UInt) {
		// Intentionally no-op: this layer never encodes draw calls.
	}

	func prerender(_ parameters: CustomLayerRenderParameters,
				   mtlCommandBuffer: any MTLCommandBuffer) -> CustomLayerRenderConfiguration {
		guard let map else { return .init() }
		// Forward parameters every frame before any drawing
		observingLayers.forEach { 
			$0.viewport.updateFrom(mapboxParameters: parameters, mapboxMap: map)
		}
		return .init()
	}

	func render(_ parameters: CustomLayerRenderParameters,
				mtlCommandBuffer: any MTLCommandBuffer,
				mtlRenderPassDescriptor: MTLRenderPassDescriptor) {
		// No drawing.
	}

	func renderingWillEnd() {
		// No-op.
	}
}
