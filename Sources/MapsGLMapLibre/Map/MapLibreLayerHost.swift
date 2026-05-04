//
//  MapLibreLayerHost.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 9/12/25.
//

import Metal
import MapsGLCore
import MapsGLMaps
import MapsGLRenderer
import MapLibre

public final class MapLibreMapsGLLayer<Layer> : MLNCustomStyleLayer where Layer : MetalLayerProtocol {
	var hostLayer: MapLibreLayerHost<Layer>
	var metalContext: MetalRenderContext?
	private var hasStartedRendering: Bool = false
	private var prerenderCommandQueue: MTLCommandQueue?
	
	init(map: MapLibre.MLNMapView, layer: Layer) throws {
		self.hostLayer = try MapLibreLayerHost(map: map, layer: layer)
		super.init(identifier: layer.id)
	}
	
	public override func didMove(to mapView: MLNMapView) {}
	
	public override func draw(in mapView: MLNMapView, with context: MLNStyleLayerDrawingContext) {
#if MLN_RENDER_BACKEND_METAL
		guard let renderEncoder = renderEncoder else { return }
		if !hasStartedRendering {
			hostLayer.renderingWillStart(renderEncoder.device)
			hasStartedRendering = true
		}
		
		// MapLibre invokes custom layer drawing with an active render encoder.
		// Run prerender on a separate command buffer to avoid nested encoder assertions.
		if let prerenderContext = createPrerenderMetalContext(renderEncoder: renderEncoder) {
			self.hostLayer.prerender(context, metalContext: prerenderContext)
			prerenderContext.commandBuffer.commit()
			prerenderContext.commandBuffer.waitUntilCompleted()
		}
		
		let metalContext = createRenderMetalContext(mapView: mapView, renderEncoder: renderEncoder)
		guard let metalContext else { return }
		self.hostLayer.render(context, metalContext: metalContext)
		restoreEncoderStateForMapLibre(renderEncoder)
#endif
	}
	
	public override func willMove(from mapView: MLNMapView) {
#if MLN_RENDER_BACKEND_METAL
		self.hostLayer.renderingWillEnd()
		self.metalContext = nil
		self.prerenderCommandQueue = nil
		self.hasStartedRendering = false
#endif
	}
	
	private func createPrerenderMetalContext(renderEncoder: MTLRenderCommandEncoder) -> MetalRenderContext? {
#if MLN_RENDER_BACKEND_METAL
		let commandQueue = prerenderCommandQueue ?? renderEncoder.device.makeCommandQueue()
		guard let commandQueue else { return nil }
		prerenderCommandQueue = commandQueue
		guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
		let context = try? MetalRenderContext.create(
			mtlDevice: renderEncoder.device,
			commandBuffer: commandBuffer,
			renderPassDescriptor: nil,
			size: .zero
		)
		return context
#endif
	}
	
	private func createRenderMetalContext(mapView: MLNMapView, renderEncoder: MTLRenderCommandEncoder) -> MetalRenderContext? {
#if MLN_RENDER_BACKEND_METAL
		let backendResource = mapView.backendResource()
		guard let commandBuffer = backendResource.commandBuffer else { return nil }
		let context = try? MetalRenderContext.create(
			mtlDevice: renderEncoder.device,
			commandBuffer: commandBuffer,
			renderPassDescriptor: nil,
			size: .zero
		)
		context?.renderEncoder = renderEncoder
		context?.ownsRenderEncoder = false
		return context
#endif
	}

	private func restoreEncoderStateForMapLibre(_ renderEncoder: MTLRenderCommandEncoder) {
		// Our layer configures mesh raster state (cull/front-facing). Restore neutral defaults
		// so subsequent MapLibre symbol rendering does not inherit triangle culling.
		renderEncoder.setCullMode(.none)
		renderEncoder.setFrontFacing(.clockwise)
		renderEncoder.setTriangleFillMode(.fill)
		renderEncoder.setDepthBias(0, slopeScale: 0, clamp: 0)
	}
}

/// A custom layer host that integrates a `MapsGLMetalLayer` with MapLibre's `CustomLayerHost`.
///
/// This class bridges MapsGL rendering into the MapLibre rendering pipeline using Metal.
/// It implements the required `CustomLayerHost` methods to control rendering lifecycle,
/// including setup, prerendering, and final rendering steps.
public final class MapLibreLayerHost<Layer> : LayerHost<Layer> where Layer : MetalLayerProtocol {
	/// The Mapbox map associated with the custom layer.
	weak var map: MapLibre.MLNMapView?
	
	/// Creates a new layer host bound to a Mapbox map and a MapsGL-compatible layer.
	/// - Parameters:
	///   - map: The Mapbox map to attach to.
	///   - layer: The MapsGL layer to manage.
	/// - Throws: An error if the superclass initialization fails.
	init(map: MapLibre.MLNMapView, layer: Layer) throws {
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
	public func renderingWillStart(_ metalDevice: MTLDevice) {
		super.beginRendering(
			metalDevice: metalDevice,
			colorPixelFormat: MTLPixelFormat.bgra8Unorm,
			depthStencilPixelFormat: MTLPixelFormat.depth32Float_stencil8
		)
	}
	
	/// Called before rendering to perform preparation work.
	/// Updates the viewport and prepares the rendering layer.
	/// - Parameters:
	///   - parameters: The render parameters provided by Mapbox.
	///   - mtlCommandBuffer: The Metal command buffer used for rendering.
	/// - Returns: A custom layer render configuration.
	public func prerender(_ parameters: MapLibre.MLNStyleLayerDrawingContext, metalContext: MetalRenderContext) {
		guard let map else { return }
		self.layer.viewport.updateFrom(maplibreContext: parameters, map: map)
		
		let context = metalContext
		context.renderTargetSize = .init(width: parameters.size.width, height: parameters.size.height)
		super.prerender(metalContext: context)
	}
	
	/// Executes the final rendering commands for the layer.
	/// - Parameters:
	///   - parameters: The render parameters provided by Mapbox.
	///   - mtlCommandBuffer: The Metal command buffer.
	///   - mtlRenderPassDescriptor: The Metal render pass descriptor.
	public func render(_ parameters: MapLibre.MLNStyleLayerDrawingContext, metalContext: MetalRenderContext) {
		let context = metalContext
		context.renderTargetSize = .init(width: parameters.size.width, height: parameters.size.height)
		super.render(metalContext: context)
	}
	
	/// Called when rendering is finished.
	/// Performs cleanup of rendering resources.
	public func renderingWillEnd() {
		super.finishRendering()
	}
}

extension MLNFillStyleLayer: PlatformStyleLayer {}
extension MLNLineStyleLayer: PlatformStyleLayer {}
extension MLNCircleStyleLayer: PlatformStyleLayer {}
extension MLNSymbolStyleLayer: PlatformStyleLayer {}
extension MLNHeatmapStyleLayer: PlatformStyleLayer {}

/// A non-rendering custom style layer that forwards MapLibre drawing context to a client.
internal final class MapLibreViewportSyncLayer: MLNCustomStyleLayer {
	internal let host: MapLibreViewportHost

	init(host: MapLibreViewportHost) {
		self.host = host
		super.init(identifier: host.id)
	}

	public override func draw(in mapView: MLNMapView, with context: MLNStyleLayerDrawingContext) {
		host.prerender(context)
	}
}

/// A non-rendering host that forwards MapLibre render context updates to registered layers.
internal final class MapLibreViewportHost {
	internal let id: String = "mapsgl-viewport-host"
	weak var map: MapLibre.MLNMapView?
	private var observingLayers: [any LayerProtocol] = []

	init(map: MapLibre.MLNMapView) {
		self.map = map
	}

	func register(layer: any LayerProtocol) {
		guard observingLayers.contains(where: { $0 as AnyObject === layer as AnyObject }) == false else { return }
		observingLayers.append(layer)
	}

	func unregister(layer: any LayerProtocol) {
		observingLayers.removeAll { $0 as AnyObject === layer as AnyObject }
	}

	var hasObservingLayers: Bool {
		observingLayers.isEmpty == false
	}

	func prerender(_ parameters: MLNStyleLayerDrawingContext) {
		guard let map else { return }
		observingLayers.forEach {
			$0.viewport.updateFrom(maplibreContext: parameters, map: map)
		}
	}
}
