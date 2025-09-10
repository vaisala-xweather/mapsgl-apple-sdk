//
//  MapboxVectorSourceAdapter.swift
//  MapsGL
//
//  Created by Nicholas Shipes on 5/28/25.
//

import MapboxMaps
import MapsGLMaps
import OSLog

/// A lightweight bridge that exposes a MapsGL `VectorTileSource` as a Mapbox
/// `CustomGeometrySource`, wiring up async tile fetch/cancel handlers.
public struct MapboxVectorSourceAdapter {
	/// The underlying MapsGL vector tile source to fetch tiles from.
	let source: VectorTileSource
	/// The target Mapbox map; held `unowned` because the controller owns both.
	unowned let map: MapboxMaps.MapboxMap

	/// Builds a `CustomGeometrySource` that fetches vector tiles from `source`.
	///
	/// - Fetches `source` metadata once (errors are logged, not thrown).
	/// - Creates async `fetchTileFunction` / `cancelTileFunction` closures:
	///   - `fetchTileFunction` requests a tile, then posts features to Mapbox on the MainActor.
	///   - `cancelTileFunction` aborts an in-flight request for the given tile.
	/// - Returns: A configured `CustomGeometrySource` ready to be added to the style.
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

	/// Invalidates a specific tile, asking Mapbox to refetch from this adapter.
	///
	/// - Parameters:
	///   - x: XYZ tile coordinate X.
	///   - y: XYZ tile coordinate Y.
	///   - z: Zoom level.
	///
	/// This method hops to the MainActor to call Mapbox’s invalidation API.
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
