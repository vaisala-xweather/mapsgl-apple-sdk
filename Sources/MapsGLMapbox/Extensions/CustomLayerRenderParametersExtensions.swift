//
//  CustomLayerRenderParametersExtensions.swift
//  MapsGLMapbox framework
//
//  Created by Slipp Douglas Thompson on 2/28/24.
//


import MapboxMaps
import Spatial



extension MapboxMaps.CustomLayerRenderParameters
{
	var projectionMatrixSIMDFloat4x4Value: simd_float4x4 {
		let sequentialProjectionMatrixValues = self.projectionMatrix.map(\.floatValue)
		return simd_float4x4(
			stride(from: 0, to: 16, by: 4)
				.map { sequentialProjectionMatrixValues[$0 ..< ($0 + 4)] }
				.map { SIMD4<Float>($0) }
		)
	}
	
	var projectionMatrixSIMDDouble4x4Value: simd_double4x4 {
		let sequentialProjectionMatrixValues = self.projectionMatrix.map(\.doubleValue)
		return simd_double4x4(
			stride(from: 0, to: 16, by: 4)
				.map { sequentialProjectionMatrixValues[$0 ..< ($0 + 4)] }
				.map { SIMD4<Double>($0) }
		)
	}
	
	var projectionMatrixSpatialValue: ProjectiveTransform3D {
		ProjectiveTransform3D(self.projectionMatrixSIMDDouble4x4Value)
	}
	
	var fieldOfViewSpatialValue: Angle2D {
		Angle2D(radians: self.fieldOfView) // Mapbox docs say `parameters.fieldOfView` is in degrees, but it's actually in radians
	}
}
