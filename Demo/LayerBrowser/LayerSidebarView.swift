//
//  LayerSidebarView.swift
//  Demo
//

import MapsGLMaps
import SwiftUI

/// The layer browser's slide-in panel: search across every weather layer, grouped
/// into collapsible categories, with the active selection pinned at the top.
struct LayerSidebarView : View {
	@ObservedObject var dataModel: WeatherLayersModel
	@Binding var isSidebarVisible: Bool

	@ObservedObject private var catalog = WeatherLayerCatalog.shared

	@State private var searchText = ""
	@State private var expandedCategories: Set<WeatherLayerCategory> = [.popular]
	@State private var isSelectionExpanded = false

	var sideBarWidth: CGFloat = 320

	private var sections: [WeatherLayerCatalog.Section] {
		catalog.sections(matching: searchText)
	}

	private var selectedLayers: [WeatherLayerItem] {
		catalog.selectedLayers(in: dataModel.selectedLayerCodes)
	}

	private var isSearching: Bool {
		!searchText.trimmingCharacters(in: .whitespaces).isEmpty
	}

	var body: some View {
		ZStack {
			if UIDevice.current.userInterfaceIdiom == .phone {
				tapOutsideToClose
			}
			content
		}
	}

	private var tapOutsideToClose: some View {
		GeometryReader { _ in
			EmptyView()
		}
		.contentShape(Rectangle())
		.opacity(isSidebarVisible ? 1 : 0)
		.onTapGesture {
			isSidebarVisible = false
		}
	}

	private var content: some View {
		GeometryReader { geometry in
			HStack(alignment: .top) {
				ZStack(alignment: .top) {
					XWColor.backgroundPrimary
						.edgesIgnoringSafeArea(.all)

					VStack(alignment: .leading, spacing: 0) {
						header
						searchField

						if catalog.isLoading && catalog.sections.isEmpty {
							ProgressView("Loading layers…")
								.font(XWFont.small)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
						} else {
							list
						}
					}
				}
				.frame(width: sideBarWidth)
				.overlay(alignment: .trailing) {
					// A border, not a shadow, separates the panel from the map.
					Rectangle()
						.fill(XWColor.border)
						.frame(width: XWBorder.hairline)
				}
				.offset(x: isSidebarVisible ? 0 : -(sideBarWidth + geometry.safeAreaInsets.leading))
				.animation(XWMotion.layout, value: isSidebarVisible)

				Spacer()
			}
		}
	}

	private var header: some View {
		HStack {
			Text("Layers")
				.xwHeading()
				.foregroundStyle(XWColor.textPrimary)
			Spacer()
			menuCloseButton
		}
		.padding(.top, XWSpace.x5)
		.padding(.trailing, XWSpace.x5)
		// Clears the back button ``ExampleContainer`` floats over every example.
		.padding(.leading, ExampleChrome.horizontalPadding + ExampleChrome.backButtonSize + XWSpace.x3)
		.padding(.bottom, XWSpace.x3)
	}

	private var menuCloseButton: some View {
		Image(systemName: "xmark")
			.font(XWFont.subheader)
			.foregroundStyle(XWColor.textTertiary)
			.frame(width: 32, height: 32)
			.contentShape(Rectangle())
			.onTapGesture {
				isSidebarVisible.toggle()
			}
			.accessibilityLabel("Close layers")
	}

	private var searchField: some View {
		HStack(spacing: XWSpace.x2) {
			Image(systemName: "magnifyingglass")
				.font(XWFont.small)
				.foregroundStyle(XWColor.textTertiary)

			TextField("Search layers", text: $searchText)
				.textFieldStyle(.plain)
				.font(XWFont.body)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)
				.foregroundStyle(XWColor.textPrimary)

			if isSearching {
				Button {
					searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.font(XWFont.small)
						.foregroundStyle(XWColor.textTertiary)
				}
				.accessibilityLabel("Clear search")
			}
		}
		.padding(.horizontal, XWSpace.x3)
		.padding(.vertical, XWSpace.x3)
		.overlay(
			RoundedRectangle(cornerRadius: XWRadius.sm, style: .continuous)
				.strokeBorder(XWColor.border, lineWidth: XWBorder.width)
		)
		.padding(.horizontal, XWSpace.x5)
		.padding(.bottom, XWSpace.x3)
	}

	private var list: some View {
		List {
			if !isSearching {
				// Always rendered, even at zero, and collapsed by default: if this
				// section appeared or grew with the selection it would push the
				// category the user is tapping in out from under their finger.
				Section {
					DisclosureGroup(isExpanded: $isSelectionExpanded) {
						if selectedLayers.isEmpty {
							Text("No layers selected.")
								.xwSmall()
								.foregroundStyle(XWColor.textSecondary)
								.padding(.horizontal, XWSpace.x5)
								.padding(.vertical, XWSpace.x2)
								.listRowBackground(XWColor.backgroundPrimary)
								.listRowInsets(EdgeInsets())
						} else {
							ForEach(selectedLayers) { layer in
								row(for: layer)
							}
						}
					} label: {
						sectionHeader("Selected", count: selectedLayers.count)
					}
					.listRowBackground(XWColor.backgroundPrimary)
					.listRowSeparatorTint(XWColor.borderSubtle)
				}
			}

			ForEach(sections) { section in
				// Searching collapses the hierarchy: matches are worth seeing without
				// a disclosure tap each.
				let isExpanded = Binding(
					get: { isSearching || expandedCategories.contains(section.category) },
					set: { expanded in
						guard !isSearching else { return }
						if expanded {
							expandedCategories.insert(section.category)
						} else {
							expandedCategories.remove(section.category)
						}
					}
				)

				Section {
					DisclosureGroup(isExpanded: isExpanded) {
						ForEach(section.layers) { layer in
							row(for: layer)
						}
					} label: {
						sectionHeader(section.category.title, count: section.layers.count)
					}
					.listRowBackground(XWColor.backgroundPrimary)
					.listRowSeparatorTint(XWColor.borderSubtle)
				}
			}

			if sections.isEmpty && isSearching {
				Text("No layers match “\(searchText)”.")
					.xwSmall()
					.foregroundStyle(XWColor.textSecondary)
					.frame(maxWidth: .infinity, alignment: .center)
					.listRowBackground(XWColor.backgroundPrimary)
			}
		}
		.listStyle(.plain)
		.tint(XWColor.textSecondary)
		.scrollContentBackground(.hidden)
		.scrollDismissesKeyboard(.interactively)
		.environment(\.defaultMinListRowHeight, 0)
	}

	private func sectionHeader(_ title: String, count: Int) -> some View {
		HStack(spacing: XWSpace.x2) {
			Text(title)
				.xwSubheader()
				.foregroundStyle(XWColor.textPrimary)
			Text("\(count)")
				.xwDataValue()
				.foregroundStyle(XWColor.textSecondary)
		}
	}

	private func row(for layer: WeatherLayerItem) -> some View {
		LayerRow(
			layer: layer,
			isSelected: dataModel.selectedLayerCodes.contains(layer.code)
		) {
			toggle(layer.code)
		}
	}

	private func toggle(_ code: WeatherService.LayerCode) {
		if dataModel.selectedLayerCodes.contains(code) {
			dataModel.selectedLayerCodes.remove(code)
		} else {
			dataModel.selectedLayerCodes.insert(code)
		}
	}
}

/// One layer in the browser: thumbnail, title, and its one-line description.
private struct LayerRow : View {
	let layer: WeatherLayerItem
	let isSelected: Bool
	let onTap: () -> Void

	var body: some View {
		HStack(spacing: XWSpace.x3) {
			thumbnail

			VStack(alignment: .leading, spacing: XWSpace.x1) {
				Text(layer.title)
					.xwSubheader()
					.foregroundStyle(XWColor.textPrimary)
					.fixedSize(horizontal: false, vertical: true)

				if !layer.summary.isEmpty {
					Text(layer.summary)
						.xwSmall()
						.foregroundStyle(XWColor.textSecondary)
						.lineLimit(2)
				}
			}

			Spacer(minLength: XWSpace.x1)

			if isSelected {
				// The one accent on this screen: which layers are drawing.
				Image(systemName: "checkmark")
					.font(XWFont.subheader)
					.foregroundStyle(XWColor.accent)
			}
		}
		.padding(.horizontal, XWSpace.x5)
		.padding(.vertical, XWSpace.x2)
		.contentShape(Rectangle())
		.onTapGesture(perform: onTap)
		.listRowBackground(isSelected ? XWColor.surfaceOverlay : XWColor.backgroundPrimary)
		.listRowSeparatorTint(XWColor.borderSubtle)
		.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
		.listRowInsets(EdgeInsets())
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
	}

	@ViewBuilder
	private var thumbnail: some View {
		if let url = layer.thumbnailURL {
			AsyncImage(url: url) { image in
				image.resizable().scaledToFill()
			} placeholder: {
				XWColor.backgroundTertiary
			}
			.frame(width: 34, height: 34)
			.clipShape(RoundedRectangle(cornerRadius: XWRadius.sm, style: .continuous))
		} else {
			RoundedRectangle(cornerRadius: XWRadius.sm, style: .continuous)
				.fill(XWColor.backgroundTertiary)
				.frame(width: 34, height: 34)
		}
	}
}

#Preview {
	LayerSidebarView(
		dataModel: WeatherLayersModel(),
		isSidebarVisible: .constant(true)
	)
}
