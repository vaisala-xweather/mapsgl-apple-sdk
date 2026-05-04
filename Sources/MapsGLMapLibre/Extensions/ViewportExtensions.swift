//
//  ViewportExtensions.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 9/13/25.
//

import CoreLocation
import MapsGLMaps
import Spatial
import struct UIKit.UIEdgeInsets
import MapLibre

extension MapsGLMaps.Viewport {
	internal static func make(maplibreContext: MapLibre.MLNStyleLayerDrawingContext, map: MapLibre.MLNMapView, retinaScale: RetinaScaleFactor? = nil) -> Self {
		var viewport = self.init(retinaScale: retinaScale)
		viewport.updateFrom(maplibreContext: maplibreContext, map: map)
		return viewport
	}
	
	internal mutating func updateFrom(maplibreContext: MapLibre.MLNStyleLayerDrawingContext, map: MapLibre.MLNMapView) {
		let maplibreBounds = map.visibleCoordinateBounds
		let centerLongitude = maplibreContext.centerCoordinate.longitude
		let unwrappedSouthwestLongitude = Self.unwrapLongitude(maplibreBounds.sw.longitude, around: centerLongitude)
		var unwrappedNortheastLongitude = Self.unwrapLongitude(maplibreBounds.ne.longitude, around: centerLongitude)
		if unwrappedNortheastLongitude < unwrappedSouthwestLongitude {
			unwrappedNortheastLongitude += 360
		}
		
		let southwest = MapCoordinate<LatitudeLongitude>(CLLocationCoordinate2D(latitude: maplibreBounds.sw.latitude, longitude: unwrappedSouthwestLongitude))
		let northeast = MapCoordinate<LatitudeLongitude>(CLLocationCoordinate2D(latitude: maplibreBounds.ne.latitude, longitude: unwrappedNortheastLongitude))
		let coordinateBounds = MapBounds(southWest: southwest, northEast: northeast)
		
		self.center = MapCoordinate<LatitudeLongitude>(maplibreContext.centerCoordinate).converted(to: UnitMercator())
		let projectionMatrix = maplibreContext.projectionMatrix
		self.projectionMatrix = ProjectiveTransform3D(simd_double4x4(
			SIMD4<Double>(projectionMatrix.m00, projectionMatrix.m01, projectionMatrix.m02, projectionMatrix.m03),
			SIMD4<Double>(projectionMatrix.m10, projectionMatrix.m11, projectionMatrix.m12, projectionMatrix.m13),
			SIMD4<Double>(projectionMatrix.m20, projectionMatrix.m21, projectionMatrix.m22, projectionMatrix.m23),
			SIMD4<Double>(projectionMatrix.m30, projectionMatrix.m31, projectionMatrix.m32, projectionMatrix.m33)
		))
		self.zoom = maplibreContext.zoomLevel
		self.bearing = .init(value: maplibreContext.direction, unit: .degrees)
		self.pitch = .init(value: maplibreContext.pitch, unit: .degrees)
		self.fovY = Angle2D(radians: Measurement(value: maplibreContext.fieldOfView, unit: UnitAngle.degrees).converted(to: .radians).value)
		self.bounds = coordinateBounds.converted(to: UnitMercator())
		self.size = CGSize(width: maplibreContext.size.width, height: maplibreContext.size.height)
	}
		
	private static func unwrapLongitude(_ longitude: Double, around referenceLongitude: Double) -> Double {
		var result = longitude
		while result - referenceLongitude > 180 {
			result -= 360
		}
		while result - referenceLongitude < -180 {
			result += 360
		}
		return result
	}
}
