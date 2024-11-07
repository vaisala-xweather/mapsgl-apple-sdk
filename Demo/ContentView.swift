//
//  ContentView.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import MapboxMaps
import MapsGLMaps



fileprivate let initialZoom: Double = 2.75
fileprivate let currentLocationZoom: Double = 4.0



struct ContentView : View
{
	@ObservedObject var dataModel: WeatherLayersModel
	@State private var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true
	
	private var mapView: RepresentedMapboxMapView!
	
	private static let locationFinder = LocationFinder()
	@State private var locationFinderAlertIsPresented: Bool = false
	@State private var locationFinderError: LocationFinder.Error? = nil {
		didSet {
			if self.locationFinderError != nil {
				self.locationFinderAlertIsPresented = true
			}
		}
	}
	
	init(dataModel: WeatherLayersModel) {
		self.dataModel = dataModel
		self.mapView = RepresentedMapboxMapView(
			mapInitOptions: .init(
				cameraOptions: .init(center: .geographicCenterOfContiguousUSA, zoom: initialZoom),
				styleURI: .dark
			),
			dataModel: self.dataModel
		)
	}
	
	
	var body: some View {
		ZStack {
			self.mapView
			.ignoresSafeArea()
			.alert(isPresented: $locationFinderAlertIsPresented, error: self.locationFinderError) {
				Button("OK") {
					self.locationFinderError = nil
				}
			}
			
			Group {
				self.layersButton
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.padding([ .top ], 30)
			
			Group {
				self.currentLocationButton
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.padding([ .bottom ], 40)
			
			SidebarView(dataModel: self.dataModel, isSidebarVisible: $isSidebarVisible)
		}
	}
	
	var layersButton: some View {
		ZStack {
			Circle()
				.fill(Color.backgroundColor)
				.frame(width: 44, height: 44)
				.shadow(color: .shadowColor, radius: 8, y: +2)
			Image("MapsGL.Stack")
				.renderingMode(.template)
				.resizable().scaledToFit().frame(width: 24, height: 24)
				.foregroundColor(.textColor)
		}
		.padding(.all, 6)
		.onTapGesture {
			self.isSidebarVisible.toggle()
		}
	}
	
	var currentLocationButton: some View {
		ZStack {
			Circle()
				.fill(Color.backgroundColor)
				.frame(width: 44, height: 44)
				.shadow(color: .shadowColor, radius: 8, y: +2)
			Image("MapsGL.Location")
				.renderingMode(.template)
				.resizable().scaledToFit().frame(width: 24, height: 24)
				.foregroundColor(.textColor)
		}
		.padding(.all, 6)
		.onTapGesture {
			ContentView.locationFinder.findCurrentLocation { location in
				self.mapView.fly(to: .init(center: location.coordinate, zoom: currentLocationZoom))
			} failure: { error in
				self.locationFinderError = error
			}
		}
	}
}



#Preview {
	ContentView(
		dataModel: WeatherLayersModel()
	)
}
