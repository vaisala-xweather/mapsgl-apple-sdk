//
//  ViewportExtensions.swift
//  
//
//  Created by Slipp Douglas Thompson on 6/26/24.
//

import CoreLocation
import MapsGLMaps
import struct UIKit.UIEdgeInsets
import MapboxMaps

extension MapsGLMaps.Viewport {
	internal static func make(mapboxParameters: MapboxMaps.CustomLayerRenderParameters, mapboxMap: MapboxMap, retinaScale: RetinaScaleFactor? = nil) -> Self {
		var viewport = self.init(retinaScale: retinaScale)
		viewport.updateFrom(mapboxParameters: mapboxParameters, mapboxMap: mapboxMap)
		return viewport
	}
	
	internal mutating func updateFrom(mapboxParameters: MapboxMaps.CustomLayerRenderParameters, mapboxMap: MapboxMap) {
		let cameraState = MapboxMaps.CameraState(
			center: CLLocationCoordinate2D(latitude: mapboxParameters.latitude, longitude: mapboxParameters.longitude),
			padding: UIEdgeInsets(),
			zoom: mapboxParameters.zoom,
			bearing: mapboxParameters.bearing,
			pitch: mapboxParameters.pitch
		)
		let coordinateBoundsUnwrapped = mapboxMap.coordinateBoundsUnwrapped(for: MapboxMaps.CameraOptions(cameraState: cameraState))
		
		self.center = MapCoordinate<LatitudeLongitude>(cameraState.center).converted(to: UnitMercator())
		self.projectionMatrix = mapboxParameters.projectionMatrixSpatialValue
		self.zoom = cameraState.zoom
		self.bearing = .init(value: cameraState.bearing, unit: .degrees)
		self.pitch = .init(value: cameraState.pitch, unit: .radians)
		self.fovY = mapboxParameters.fieldOfViewSpatialValue
		self.bounds = MapBounds<LatitudeLongitude>(coordinateBoundsUnwrapped).converted(to: UnitMercator())
		self.size = CGSize(width: mapboxParameters.width, height: mapboxParameters.height)
	}
}
