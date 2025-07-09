import SwiftUI
import MapsGLMaps

struct SidebarView : View {
	@ObservedObject var dataModel: WeatherLayersModel
	@Binding var isSidebarVisible: Bool
    @State private var selectedCategory: WeatherLayersModel.Category = .all
	
	var sideBarWidth: CGFloat = 300
	
	var body: some View {
		ZStack {
			if UIDevice.current.userInterfaceIdiom == .phone {
				self.tapOutsideToClose
			}
            if WeatherLayersModel.store.isLoading {
                ProgressView("Loading layers...").padding()
            } else {
                self.content
            }
		}.environment(\.colorScheme, .dark)
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
        GeometryReader { geometry in
            HStack(alignment: .top) {
                ZStack(alignment: .top) {
                    Color.backgroundColor
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(alignment: .leading) {
                        self.title

                        HStack {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(WeatherLayersModel.Category.allCases) { category in
                                    Text(category.title).tag(Optional(category))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tint(.white)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.cellDividerColor, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        self.list
                    }
                }
                    .frame(width: self.sideBarWidth)
                    .offset(x: self.isSidebarVisible ? 0 : -(self.sideBarWidth + geometry.safeAreaInsets.leading))
                    .animation(.default, value: self.isSidebarVisible)
                
                Spacer()
            }
        }
    }
	
	var title: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("Layers")
					.font(.titleFont)
					.lineSpacing(20)
					.foregroundColor(.textColor)
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
			.foregroundColor(.closeButtonColor)
			.padding(.all, 0)
			.animation(.default, value: self.isSidebarVisible)
			.onTapGesture {
				self.isSidebarVisible.toggle()
			}
	}
	
    var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let layers = WeatherLayersModel.store.allLayersByCategory()[selectedCategory] {
                    CellGroup(
                        headerText: selectedCategory.title,
                        items: layers,
                        selectedLayerCodes: $dataModel.selectedLayerCodes
                    )
                }
            }
        }
    }
}

struct CellGroup : View {
	var headerText: String
	var items: [WeatherLayersModel.Layer]
	@Binding var selectedLayerCodes: Set<WeatherLayersModel.Layer.ID>
	
	var body: some View {		
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
			.frame(minHeight: CGFloat(36 * self.items.count))
	}
	
	var header: some View {
		HStack {
			Text(self.headerText)
				.font(.headerFont)
				.lineSpacing(20)
				.foregroundColor(.textColor)
				.frame(height: 28)
			Spacer()
		}
			.padding(.top, 28)
			.padding(.horizontal, 20)
			.padding(.bottom, 12)
	}
}

struct CellListItem : View {
	var text: String
	var selected: Bool = false
	
	var body: some View {
		HStack {
			Text(text)
				.font(.cellFont)
				.lineSpacing(20)
				.foregroundColor(self.selected ? .textHighlightedColor : .textColor)
				.font(.body)
			Spacer()
		}
			.padding(.horizontal, 20)
			.padding(.vertical, 6)
			.frame(height: 36)
			.contentShape(Rectangle())
			.listRowBackground(
				self.selected ? Color.backgroundHighlightedColor : Color.backgroundColor
			)
			.listRowSeparatorTint(.cellDividerColor)
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
