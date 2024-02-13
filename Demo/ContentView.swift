//
//  ContentView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import MapboxMaps
import MapsGLMaps



struct ContentView : View
{
	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
	
	
	var body: some View {
		ZStack(alignment: .topLeading) {
			RepresentedMapboxMapView(	
				mapInitOptions: .init(
					cameraOptions: .init(center: .geographicCenterOfContiguousUSA, zoom: 2),
					styleURI: .light
				),
				dataModel: self.dataModel
			)
			.ignoresSafeArea()
			
			self.layersButton
			
			SidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
		}
	}
	
	var layersButton: some View {
		ZStack {
			Circle()
				.fill(Color.backgroundColor)
				.frame(width: 44, height: 44)
				.shadow(color: .shadowColor, radius: 8, y: +2)
			Image(systemName: "square.3.layers.3d.top.filled")
				.resizable().scaledToFit().frame(width: 24, height: 24)
				.foregroundColor(.textColor)
		}
		.padding(.all, 12)
		.padding(.top, 24)
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
