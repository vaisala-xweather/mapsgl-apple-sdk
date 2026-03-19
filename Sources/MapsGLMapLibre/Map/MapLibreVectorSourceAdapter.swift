//
//  MapLibreVectorSourceAdapter.swift
//  MapsGL
//
//  Created by Anthony Pardee on 12/17/25.
//

import Foundation
import MapLibre
import MapsGLMaps
import OSLog
import Turf

/// Bridges a MapsGL `VectorTileSource` to a MapLibre `MLNComputedShapeSource`.
final class MapLibreVectorSourceAdapter: NSObject {
	/// The backing MapsGL data source.
	private let source: VectorTileSource
	/// Weak reference to the MapLibre computed source so we can invalidate tiles on demand.
	private weak var computedSource: MLNComputedShapeSource?
	/// JSON encoder for converting Turf features into GeoJSON blobs MapLibre understands.
	private let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .millisecondsSince1970
		return encoder
	}()
	
	init(source: VectorTileSource) {
		self.source = source
	}
	
	/// Creates the MapLibre `MLNComputedShapeSource` and kickstarts metadata fetching.
	func makeSource() async -> MLNComputedShapeSource {
		do {
			try await source.fetchMetadata()
		} catch {
			Logger.map.error("Failed to fetch metadata for vector tile source \(self.source.id): \(error.localizedDescription)")
		}
		
		let options: [MLNShapeSourceOption : Any] = [
			MLNShapeSourceOption.minimumZoomLevel: NSNumber(value: source.zoomRange.lowerBound),
			MLNShapeSourceOption.maximumZoomLevel: NSNumber(value: source.zoomRange.upperBound)
		]
		
		let computedSource = MLNComputedShapeSource(
			identifier: source.id,
			dataSource: self,
			options: options
		)
		self.computedSource = computedSource
		return computedSource
	}
	
	/// Invalidates a single tile on the MapLibre source when MapsGL marks it stale.
	func invalidate(x: Int, y: Int, z: Int) {
		source.abortTile(x: x, y: y, z: z)
		computedSource?.invalidateTileAt(x: UInt(x), y: UInt(y), zoomLevel: UInt(z))
	}
}

extension MapLibreVectorSourceAdapter: MLNComputedShapeSourceDataSource {
	@objc func featuresInTileAt(x: UInt, y: UInt, zoomLevel: UInt) -> [MLNShape & MLNFeature] {
		let tileCoord = TileCoord(x: Int(x), y: Int(y), z: Int(zoomLevel))
		return requestFeaturesSynchronously(for: tileCoord)
	}
	
	private func requestFeaturesSynchronously(for tileCoord: TileCoord) -> [MLNShape & MLNFeature] {
		let semaphore = DispatchSemaphore(value: 0)
		var result: [MLNShape & MLNFeature] = []
		
		Task { [weak self] in
			defer { semaphore.signal() }
			guard let self else { return }
			do {
				guard let data = try await self.source.requestTile(x: tileCoord.x, y: tileCoord.y, z: tileCoord.z) else {
					return
				}
				let converted = self.convert(features: data.features)
				result = converted
			} catch {
				Logger.map.error("Failed to fetch MapLibre tile (\(tileCoord.x), \(tileCoord.y), \(tileCoord.z)) for source \(self.source.id): \(error.localizedDescription)")
			}
		}
		semaphore.wait()
		return result
	}
	
	private func convert(features: [Turf.Feature]) -> [MLNShape & MLNFeature] {
		guard !features.isEmpty else { return [] }
		
		let collection = Turf.FeatureCollection(features: features)
		guard let encoded = try? encoder.encode(collection) else {
			return []
		}
		
		let geoJSON = try? MLNShape(data: encoded, encoding: String.Encoding.utf8.rawValue)
		if let shapeCollection = geoJSON as? MapLibre.MLNShapeCollectionFeature {
			return shapeCollection.shapes
		} else if let singleFeature = geoJSON as? (MLNShape & MLNFeature) {
			return [singleFeature]
		}
		
		return []
	}
}
