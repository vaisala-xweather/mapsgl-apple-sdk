//
//  MapboxVectorSourceAdapter.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 5/28/25.
//

import MapboxMaps
import MapsGLMaps
import OSLog

public struct MapboxVectorSourceAdapter {
	let source: VectorTileSource
	unowned let map: MapboxMaps.MapboxMap

	func makeSource() async -> CustomGeometrySource {
		do {
			try await source.fetchMetadata()
		} catch {
			Logger.map.error("Failed to fetch metadata for vector tile source: \(error)")
		}
		
		return CustomGeometrySource(
			id: source.id,
			options: CustomGeometrySourceOptions(
				fetchTileFunction: { tileID in
					Task {
						if let data = try await source.requestTile(x: Int(tileID.x), y: Int(tileID.y), z: Int(tileID.z)) {
							try await MainActor.run {
								try map.setCustomGeometrySourceTileData(forSourceId: source.id, tileId: tileID, features: data.features)
							}
						}
					}
				},
				cancelTileFunction: { tileID in
					source.abortTile(x: Int(tileID.x), y: Int(tileID.y), z: Int(tileID.z))
				},
				minZoom: UInt8(source.zoomRange.lowerBound),
				maxZoom: UInt8(source.zoomRange.upperBound),
				tileOptions: TileOptions()
			)
		)
	}

	func invalidate(x: Int, y: Int, z: Int) {
		Task { @MainActor in
			do {
				let tileID = CanonicalTileID(z: UInt8(z), x: UInt32(x), y: UInt32(y))
				try map.invalidateCustomGeometrySourceTile(forSourceId: source.id, tileId: tileID)
			} catch {
				Logger.map.error(error.localizedDescription)
			}
		}
	}
}
