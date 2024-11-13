//
//  DemoApp.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/7/24.
//

import SwiftUI
import MapboxMaps



@main
struct DemoApp : App
{
	private var _dataModel = WeatherLayersModel(
		selectedLayerCodes: [ .windParticles ]
	)
	
	init() {
		MapboxOptions.accessToken = AccessKeys.shared.mapboxAccessToken
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView(dataModel: _dataModel)
		}
	}
}
