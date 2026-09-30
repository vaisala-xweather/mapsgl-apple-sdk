//
//  WeatherLayersModel.swift
//  Demo
//

import Combine
import Foundation
import MapsGLMaps

/// The layer browser's selection state.
class WeatherLayersModel : ObservableObject {
	@Published var selectedLayerCodes: Set<WeatherService.LayerCode>

	init(selectedLayerCodes: Set<WeatherService.LayerCode> = []) {
		self.selectedLayerCodes = selectedLayerCodes
	}
}

extension WeatherService.LayerCode {
	/// Whether this is a data-query text layer (e.g. temperature/wind-speed values at point locations), which visually competes with the base map's own place-name labels.
	var isDataQueryTextLayer: Bool {
		rawValue.hasSuffix("-text")
	}
}

/// Addresses one row in the layer browser.
///
/// A row is currently one ``WeatherService/LayerCode``. Once a layer can be drawn
/// from a specific numerical model, a row becomes a base code paired with a model,
/// and the browser gains a model filter rather than one row per code-and-model
/// combination. Keeping rows behind this type means that change lands here instead
/// of in every view that renders one.
struct LayerRowID : Hashable, Identifiable {
	let code: WeatherService.LayerCode

	var id: String { code.rawValue }

	init(_ code: WeatherService.LayerCode) {
		self.code = code
	}
}

/// One selectable weather layer, with everything the browser renders precomputed.
struct WeatherLayerItem : Identifiable {
	let id: LayerRowID
	var title: String
	var summary: String
	var thumbnailURL: URL?
	var categories: [WeatherLayerCategory]

	/// Lowercased title, code and summary, joined once so filtering is a substring
	/// scan rather than three case-insensitive comparisons per row per keystroke.
	private(set) var searchHaystack: String

	var code: WeatherService.LayerCode { id.code }

	init(
		code: WeatherService.LayerCode,
		title: String,
		summary: String = "",
		thumbnailURL: URL? = nil,
		categories: [WeatherLayerCategory] = []
	) {
		self.id = LayerRowID(code)
		self.title = title
		self.summary = summary
		self.thumbnailURL = thumbnailURL
		self.categories = categories
		self.searchHaystack = "\(title)\n\(code.rawValue)\n\(summary)".lowercased()
	}

	func matches(_ lowercasedTerm: String) -> Bool {
		lowercasedTerm.isEmpty || searchHaystack.contains(lowercasedTerm)
	}
}

/// The categories the browser groups layers into, mirroring the weather API's own.
enum WeatherLayerCategory : String, CaseIterable, Identifiable, Comparable {
	case popular = "popular"
	case radarSatellite = "radar-satellite"
	case conditions = "conditions"
	case forecasts = "forecasts"
	case severe = "severe"
	case tropical = "tropical"
	case lightning = "lightning"
	case airQuality = "air-quality"
	case maritime = "maritime"
	case climate = "climate"
	case admin = "admin"
	case other = "other"

	var id: Self { self }

	var title: String {
		switch self {
		case .popular: "Popular"
		case .radarSatellite: "Radar/Satellite"
		case .conditions: "Conditions"
		case .forecasts: "Forecasts"
		case .severe: "Severe"
		case .tropical: "Tropical"
		case .lightning: "Lightning"
		case .airQuality: "Air Quality"
		case .maritime: "Maritime"
		case .climate: "Climate"
		case .admin: "Admin"
		case .other: "Other"
		}
	}

	/// Declaration order, so sections appear most-used first rather than alphabetically.
	private var rank: Int {
		Self.allCases.firstIndex(of: self) ?? Self.allCases.count
	}

	static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }

	/// Maps a category name as the weather API spells it (`"Air Quality"`, `"Radar + Satellite"`).
	init?(apiName: String) {
		let slug = apiName
			.lowercased()
			.replacingOccurrences(of: " + ", with: "-")
			.replacingOccurrences(of: " ", with: "-")
		self.init(rawValue: slug)
	}
}

/// The browser's layer catalog: every layer, grouped and indexed once.
///
/// Grouping is computed when metadata arrives, not on demand. The browser renders
/// hundreds of rows and will render considerably more once model layers exist, so
/// rebuilding a category dictionary per view update is not affordable.
@MainActor
final class WeatherLayerCatalog : ObservableObject {
	static let shared = WeatherLayerCatalog()

	struct Section : Identifiable {
		let category: WeatherLayerCategory
		let layers: [WeatherLayerItem]

		var id: WeatherLayerCategory { category }
	}

	@Published private(set) var isLoading = false
	@Published private(set) var sections: [Section] = []
	@Published private(set) var layersByCode: [WeatherService.LayerCode : WeatherLayerItem] = [:]

	/// Region-specific layers are reachable through their composite parents.
	private static let regionSuffixes = ["-us", "-europe", "-japan", "-australia", "-new-zealand"]

	private var didLoad = false

	private init() {
		rebuild(with: Self.placeholderLayers())
	}

	/// Every layer code, titled by its raw value, for the window before metadata arrives.
	private static func placeholderLayers() -> [WeatherLayerItem] {
		WeatherService.LayerCode.allCases
			.filter { code in !regionSuffixes.contains { code.rawValue.hasSuffix($0) } }
			.map { WeatherLayerItem(code: $0, title: $0.rawValue, categories: [.other]) }
	}

	/// Fetches titles, descriptions, thumbnails and categories, then regroups. Runs once.
	func load(service: WeatherService) {
		guard !didLoad else { return }
		didLoad = true
		isLoading = true

		service.loadLayerMetadata { [weak self] result in
			Task { @MainActor in
				guard let self else { return }
				defer { self.isLoading = false }

				switch result {
				case .success(let metadata):
					self.rebuild(with: Self.merge(metadata: metadata))
				case .failure(let error):
					// The placeholder catalog stays usable; only titles and grouping suffer.
					print("Failed to fetch layer metadata: \(error)")
					self.didLoad = false
				}
			}
		}
	}

	private static func merge(metadata: [WeatherLayerMetadata]) -> [WeatherLayerItem] {
		let byId = Dictionary(metadata.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

		return placeholderLayers().map { placeholder in
			guard let entry = byId[placeholder.code.rawValue] else {
				return placeholder
			}

			let categories = entry.categories.compactMap(WeatherLayerCategory.init(apiName:))
			return WeatherLayerItem(
				code: placeholder.code,
				title: entry.title,
				summary: entry.description,
				thumbnailURL: entry.imageUrl,
				categories: categories.isEmpty ? [.other] : categories
			)
		}
	}

	private func rebuild(with layers: [WeatherLayerItem]) {
		let sorted = layers.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }

		layersByCode = Dictionary(sorted.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
		sections = Self.group(sorted)
	}

	private static func group(_ layers: [WeatherLayerItem]) -> [Section] {
		var buckets: [WeatherLayerCategory : [WeatherLayerItem]] = [:]
		for layer in layers {
			for category in layer.categories {
				buckets[category, default: []].append(layer)
			}
		}

		return buckets
			.map { Section(category: $0.key, layers: $0.value) }
			.sorted { $0.category < $1.category }
	}

	/// Sections holding only the layers matching `term`, dropping any that empty out.
	func sections(matching term: String) -> [Section] {
		let needle = term.lowercased()
		guard !needle.isEmpty else { return sections }

		return sections.compactMap { section in
			let matched = section.layers.filter { $0.matches(needle) }
			return matched.isEmpty ? nil : Section(category: section.category, layers: matched)
		}
	}

	/// The selected layers, in catalog order, for the browser's pinned section.
	func selectedLayers(in selection: Set<WeatherService.LayerCode>) -> [WeatherLayerItem] {
		selection
			.compactMap { layersByCode[$0] }
			.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
	}
}
