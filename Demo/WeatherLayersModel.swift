//
//  WeatherLayersModel.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/12/24.
//

import Combine
import MapsGLMaps

/// View-model for weather layers, bridging MapsGL's `WeatherService` model to Demo app's ``RepresentedMapboxMapView`` view, and ownership of view selected layer state.
class WeatherLayersModel : ObservableObject {
	@Published var selectedLayerCodes: Set<WeatherService.LayerCode>
	
    init(selectedLayerCodes: Set<WeatherService.LayerCode> = []) {
		self.selectedLayerCodes = selectedLayerCodes
	}
}

// MARK: Constant Layer Configurations

extension WeatherLayersModel {
    class Metadata {
        @Published var isLoading: Bool = false
        var layerMetadata: [WeatherLayerMetadata] = []
        
        var allLayers: [Layer]
        
        init() {
            let regions = ["-us", "-europe", "-japan", "-australia", "-new-zealand"]
            allLayers = WeatherService.LayerCode.allCases.filter { code in
                // Remove region-specific layers from list as they're included in parent composite layers
                !regions.contains { region in code.rawValue.hasSuffix(region) }
            }.map { code in
                .init(
                    code: code,
                    title: code.rawValue,
                    categories: [.all]
                )
            }.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
        
        func allLayersByCode() -> [WeatherService.LayerCode : Layer] {
            return Dictionary.init(uniqueKeysWithValues: allLayers.map { layer in
                ( key: layer.code, value: layer )
            })
        }
        
        func allLayersByCategory() -> [Category : [Layer]] {
            return Dictionary.init(uniqueKeysWithValues: Category.allCases.map { category in
                ( key: category, value: allLayers.filter { $0.categories.contains(where: { $0 == category }) } )
            })
        }
        
        func loadMetadata(service: WeatherService, callback: (() -> Void)? = nil) {
            isLoading = true
            Task.detached {
                service.loadLayerMetadata() { [weak self] result in
                    switch result {
                    case .success(let loadedLayers):
                        var categories: [String] = []
                        loadedLayers.forEach { metadata in
                            metadata.categories.map {
                                $0.lowercased()
                                    .replacingOccurrences(of: " + ", with: "-")
                                    .replacingOccurrences(of: " ", with: "-")
                            }.forEach { cat in
                                if categories.contains(where: { $0.lowercased() == cat }) == false {
                                    categories.append(cat)
                                }
                            }
                        }
                        categories = categories.sorted { $0.localizedCompare($1) == .orderedAscending }
                        self?.layerMetadata = loadedLayers
                        
                        if let layers = self?.allLayers {
                            self?.allLayers = layers.map { layer in
                                var updated = layer
                                if let metadata = loadedLayers.first(where: { $0.id == layer.code.rawValue }) {
                                    updated.title = metadata.title
                                    updated.categories = metadata.categories.compactMap {
                                        let categoryName = $0.lowercased()
                                            .replacingOccurrences(of: " + ", with: "-")
                                            .replacingOccurrences(of: " ", with: "-")
                                        return Category(rawValue: categoryName)
                                    }
                                    updated.categories.append(.all)
                                }
                                return updated
                            }.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
                        }
                        
                        callback?()
                    case .failure(let error):
                        print("Failed to fetch layer metadata: ", error)
                    }
                    self?.isLoading = false
                }
            }
        }
        
        private func metadata(for code: WeatherService.LayerCode) -> WeatherLayerMetadata? {
            return layerMetadata.first(where: { $0.id == code.rawValue })
        }
    }
    
    static let store: Metadata = .init()
	
	enum Category : String, CaseIterable, Identifiable {
        case all = "all"
        case admin = "admin"
        case airQuality = "air-quality"
        case climate = "climate"
		case conditions = "conditions"
        case forecasts = "forecasts"
        case lightning = "lightning"
		case maritime = "maritime"
        case other = "other"
        case popular = "popular"
        case radarSatellite = "radar-satellite"
        case severe = "severe"
        case tropical = "tropical"
		
		var id: Self { self }
		
		var title: String {
			switch self {
            case .all: "All"
            case .admin: "Admin"
            case .airQuality: "Air Quality"
            case .climate: "Climate"
            case .conditions: "Conditions"
            case .forecasts: "Forecasts"
            case .lightning: "Lightning"
            case .maritime: "Maritime"
            case .other: "Other"
            case .popular: "Popular"
            case .radarSatellite: "Radar/Satellite"
            case .severe: "Severe"
            case .tropical: "Tropical"
			}
		}
	}
	
	struct Layer : Identifiable {
		let code: WeatherService.LayerCode
		var id: WeatherService.LayerCode { self.code }
        var title: String
        var categories: [Category]
	}
}
