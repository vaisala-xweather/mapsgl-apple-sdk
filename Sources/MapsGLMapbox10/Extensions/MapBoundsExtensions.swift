//
//  MapBoundsExtensions.swift
//  MapsGLMapbox10 framework
//
//  Created by Slipp Douglas Thompson on 9/28/23.
//

import MapsGLMaps
import MapboxMaps



extension MapBounds where Space == LatitudeLongitude
{
	public init(_ coordinateBounds: MapboxMaps.CoordinateBounds) {
		self.init(southWest: coordinateBounds.southwest, northEast: coordinateBounds.northeast)
	}
}
