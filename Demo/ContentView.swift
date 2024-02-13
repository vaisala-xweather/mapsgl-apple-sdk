//
//  ContentView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import MapsGLMaps



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
fileprivate let shadowColor = Color(.init(
	red: 0.0,
	green: 0,
	blue: 0,
	alpha: 0.15
))



struct ContentView : View
{
	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = false
	
	
	var body: some View {
		ZStack(alignment: .topLeading) {
			ScrollView([.horizontal, .vertical], showsIndicators: false) {
				Image("PlaceholderMap")
			}
			.ignoresSafeArea(.all)
			.defaultScrollAnchor(.center)
			
			self.layersButton
			
			SidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
		}
	}
	
	var layersButton: some View {
		ZStack {
			Circle()
				.fill(backgroundColor)
				.frame(width: 44, height: 44)
				.padding(.all, 12.0)
				.shadow(color: shadowColor, radius: 8, y: +2)
			Image(systemName: "square.3.layers.3d.top.filled")
				.resizable().scaledToFit().frame(width: 24, height: 24)
				.foregroundColor(textColor)
		}
		.onTapGesture {
			self.isSidebarVisible.toggle()
		}
	}
}



#Preview {
	ContentView(
		dataModel: WeatherLayersModel()
	)
}
