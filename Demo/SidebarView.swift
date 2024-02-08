import SwiftUI



fileprivate let backgroundColor = Color(.init(
	red: 0x14 / 255,
	green: 0x18 / 255,
	blue: 0x1A / 255,
	alpha: 1
))
fileprivate let textColor = Color(.init(
	red: 0xFF / 255,
	green: 0xFF / 255,
	blue: 0xFF / 255,
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




struct MenuItem : Identifiable {
	var id: Int
	var text: String
}



struct SidebarView : View
{
	@Binding var isSidebarVisible: Bool
	
	var sideBarWidth: CGFloat = 250
	
	var body: some View {
		ZStack {
			GeometryReader { _ in
				EmptyView()
			}
			.opacity(isSidebarVisible ? 1 : 0)
			.animation(.easeInOut.delay(0.2), value: isSidebarVisible)
			.onTapGesture {
				isSidebarVisible.toggle()
			}
			
			self.content
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
				CellGroup(headerText: "Conditions", items: self.conditionsItems)
				CellGroup(headerText: "Severe", items: self.severeItems)
				CellGroup(headerText: "Other", items: self.otherItems)
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
	
	var conditionsItems: [MenuItem] = [
		MenuItem(id: 4001, text: "Temperatures"),
		MenuItem(id: 4002, text: "Wind Speeds"),
		MenuItem(id: 4003, text: "Radar"),
		MenuItem(id: 4004, text: "Satellite"),
		MenuItem(id: 4005, text: "Air Quality"),
		MenuItem(id: 4006, text: "Heat Index"),
		MenuItem(id: 4007, text: "Dew Points"),
	]
	
	var severeItems: [MenuItem] = [
		MenuItem(id: 5001, text: "Temperatures"),
		MenuItem(id: 5002, text: "Wind Speeds"),
		MenuItem(id: 5003, text: "Radar"),
		MenuItem(id: 5004, text: "Satellite"),
		MenuItem(id: 5005, text: "Air Quality"),
		MenuItem(id: 5006, text: "Heat Index"),
		MenuItem(id: 5007, text: "Dew Points"),
	]
	
	var otherItems: [MenuItem] = [
		MenuItem(id: 6001, text: "Temperatures"),
		MenuItem(id: 6002, text: "Wind Speeds"),
		MenuItem(id: 6003, text: "Radar"),
		MenuItem(id: 6004, text: "Satellite"),
		MenuItem(id: 6005, text: "Air Quality"),
		MenuItem(id: 6006, text: "Heat Index"),
		MenuItem(id: 6007, text: "Dew Points"),
	]
}


struct CellGroup : View
{
	var headerText: String
	var items: [MenuItem]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			self.header
			Divider().overlay(cellDividerColor)
			ForEach(items) { item in
				CellListItem(text: item.text)
				Divider().overlay(cellDividerColor)
			}
		}
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
	var body: some View {
		HStack {
			Text(text)
				.font(cellFont)
				.lineSpacing(20)
				.foregroundColor(textColor)
				.font(.body)
			Spacer()
			Image(systemName: "slider.horizontal.3")
				.resizable().scaledToFit().frame(width: 16, height: 16, alignment: .centerFirstTextBaseline)
				.foregroundColor(backgroundColor)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 6)
		.frame(height: 32)
		.onTapGesture {
			print("Tapped on \(text)")
		}
	}
}



#Preview {
	SidebarView(isSidebarVisible: .constant(true))
}
