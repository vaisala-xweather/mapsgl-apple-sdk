import SwiftUI
import MapsGLMaps



fileprivate let backgroundColor = Color(.init(
	red: 0x14 / 255,
	green: 0x18 / 255,
	blue: 0x1A / 255,
	alpha: 1
))
fileprivate let backgroundHighlightedColor = Color(.init(
	red: 0xFF / 255,
	green: 0xFF / 255,
	blue: 0xFF / 255,
	alpha: 1
))
fileprivate let textColor = Color(.init(
	red: 0xFF / 255,
	green: 0xFF / 255,
	blue: 0xFF / 255,
	alpha: 1
))
fileprivate let textHighlightedColor = Color(.init(
	red: 0x33 / 255,
	green: 0x33 / 255,
	blue: 0x33 / 255,
	alpha: 1
))
fileprivate let closeButtonColor = Color(.init(
	red: 0x5D / 255,
	green: 0x5D / 255,
	blue: 0x5D / 255,
	alpha: 1
))
fileprivate let cellDividerColor = Color(.init(
	red: 120 / 255,
	green: 133 / 255,
	blue: 140 / 255,
	alpha: 1
))

fileprivate let titleFont = Font.custom("Inter", size: 28)
fileprivate let headerFont = Font.custom("Inter", size: 20).weight(.medium)
fileprivate let cellFont = Font.custom("Inter", size: 12).weight(.medium)



struct SidebarView : View
{
	@ObservedObject var dataModel: WeatherLayersModel
	@Binding var isSidebarVisible: Bool
	
	var sideBarWidth: CGFloat = 250
	
	var body: some View {
		ZStack {
			self.tapOutsideToClose
			self.content
		}
	}
	
	var tapOutsideToClose: some View {
		return GeometryReader { _ in
			EmptyView()
		}
		.contentShape(Rectangle())
		.opacity(self.isSidebarVisible ? 1 : 0)
		.onTapGesture {
			self.isSidebarVisible = false
		}
	}
	
	var content: some View {
		HStack(alignment: .top) {
			ZStack(alignment: .top) {
				backgroundColor
					.edgesIgnoringSafeArea(.all)
				
				VStack(alignment: .leading) {
					self.title
					self.list
					self.footer
				}
			}
			.frame(width: self.sideBarWidth)
			.offset(x: self.isSidebarVisible ? 0 : -self.sideBarWidth)
			.animation(.default, value: self.isSidebarVisible)
			
			Spacer()
		}
	}
	
	var title: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("Layers")
					.font(titleFont)
					.lineSpacing(20)
					.foregroundColor(textColor)
				Spacer()
				self.menuCloseButton
			}
			.padding([.top, .horizontal], 20)
			.padding(.bottom, 12)
		}
	}

	var menuCloseButton: some View {
		Image(systemName: "xmark")
			.resizable().scaledToFit().frame(width: 16, height: 16)
			.foregroundColor(closeButtonColor)
			.padding(.all, 0)
			.animation(.default, value: self.isSidebarVisible)
			.onTapGesture {
				self.isSidebarVisible.toggle()
			}
	}
	
	var list: some View {
		ScrollView {
			VStack(spacing: 0) {
				ForEach(Array(WeatherLayersModel.Category.allCases)) { category in
					CellGroup(
						headerText: category.title,
						items: WeatherLayersModel.allLayersByCategory[category]!,
						selectedLayerCodes: $dataModel.selectedLayerCodes
					)
				}
			}
		}
	}
	
	var footer: some View {
		VStack(alignment: .leading) {
			HStack {
				self.settingsButton
			}
			.frame(height: 44)
		}
		.padding(.all, 20)
	}

	var settingsButton: some View {
		Image(systemName: "gearshape.fill")
			.resizable().scaledToFit().frame(width: 24, height: 24)
			.foregroundColor(textColor)
			.padding(.all, 0)
	}
}


struct CellGroup : View
{
	var headerText: String
	var items: [WeatherLayersModel.Layer]
	@Binding var selectedLayerCodes: Set<WeatherLayersModel.Layer.ID>
	
	var body: some View {
		self.header
		
		Divider().overlay(cellDividerColor)
		
		List(self.items) { item in
			CellListItem(text: item.title, selected: self.selectedLayerCodes.contains(item.id))
				.onTapGesture {
					if !self.selectedLayerCodes.contains(item.id) {
						self.selectedLayerCodes.update(with: item.id)
					} else {
						self.selectedLayerCodes.remove(item.id)
					}
				}
		}
		.listStyle(.plain)
		.environment(\.defaultMinListRowHeight, 0)
		.frame(minHeight: CGFloat(32 * self.items.count))
	}
	
	var header: some View {
		HStack {
			Text(self.headerText)
				.font(headerFont)
				.lineSpacing(20)
				.foregroundColor(textColor)
				.frame(height: 28)
			Spacer()
			Image(systemName: "thermometer.medium")
				.resizable().scaledToFit().frame(width: 28, height: 28, alignment: .centerFirstTextBaseline)
				.foregroundColor(textColor)
		}
		.padding(.top, 28)
		.padding(.horizontal, 20)
		.padding(.bottom, 12)
	}
}


struct CellListItem : View
{
	var text: String
	var selected: Bool = false
	
	var body: some View {
		HStack {
			Text(text)
				.font(cellFont)
				.lineSpacing(20)
				.foregroundColor(self.selected ? textHighlightedColor : textColor)
				.font(.body)
			Spacer()
			Image(systemName: "slider.horizontal.3")
				.resizable().scaledToFit().frame(width: 16, height: 16, alignment: .centerFirstTextBaseline)
				.foregroundColor(backgroundColor)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 6)
		.frame(height: 32)
		.contentShape(Rectangle())
		.listRowBackground(
			self.selected ? backgroundHighlightedColor : backgroundColor
		)
		.listRowSeparatorTint(cellDividerColor)
		.alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
		.listRowInsets(EdgeInsets())
	}
}



#Preview {
	SidebarView(
		dataModel: WeatherLayersModel(),
		isSidebarVisible: .constant(true)
	)
}
