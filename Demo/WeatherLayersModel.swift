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
            allLayers = WeatherService.LayerCode.allCases.map { code in
                .init(
                    code: code,
                    title: code.rawValue,
                    category: .all
                )
            }
        }
        
        func allLayersByCode() -> [WeatherService.LayerCode : Layer] {
            return Dictionary.init(uniqueKeysWithValues: allLayers.map { layer in
                ( key: layer.code, value: layer )
            })
        }
        
        func allLayersByCategory() -> [Category : [Layer]] {
            return Dictionary.init(uniqueKeysWithValues: Category.allCases.map { category in
                ( key: category, value: allLayers.filter { $0.category == category } )
            })
        }
        
        func loadMetadata(service: WeatherService) {
            isLoading = true
            service.loadLayerMetadata() { [weak self] result in
                switch result {
                case .success(let loadedLayers):
                    self?.layerMetadata = loadedLayers
                    if let layers = self?.allLayers {
                        self?.allLayers = layers.map { layer in
                            var updated = layer
                            if let metadata = loadedLayers.first(where: { $0.id == layer.code.rawValue }) {
                                updated.title = metadata.title
                            }
                            return updated
                        }
                    }
                case .failure(let error):
                    print("Failed to fetch layer metadata: ", error)
                }
                self?.isLoading = false
            }
        }
        
        private func metadata(for code: WeatherService.LayerCode) -> WeatherLayerMetadata? {
            return layerMetadata.first(where: { $0.id == code.rawValue })
        }
    }
    
    static let store: Metadata = .init()
	
	enum Category : CaseIterable, Identifiable {
        case all
		case conditions
		case airQuality
		case maritime
		
		var id: Self { self }
		
		var title: String {
			switch self {
                case .all: "All"
				case .conditions: "Conditions"
				case .airQuality: "Air Quality"
				case .maritime: "Maritime"
			}
		}
	}
	
	struct Layer : Identifiable {
		let code: WeatherService.LayerCode
		var id: WeatherService.LayerCode { self.code }
        var title: String
        var category: Category
	}
}
