//
//  ViewController.swift
//  DemoUIKit
//
//  Created by Slipp Douglas Thompson on 7/10/24.
//

import Combine
import UIKit
import MapboxMaps
import MapsGLMaps
import MapsGLMapbox



fileprivate let initialZoom: Double = 2.75



class ViewController : UIViewController
{
	@IBOutlet private var mapView: MapboxMaps.MapView!
	
	/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the ``MapboxMaps.MapView``.
	private var _mapController: MapboxMapController!
	
	/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
	/// Used for change-checking in comparison to the ``dataModel.selectedLayerCodes`` to determine if there are new layers that need to be added, or old layers that need to be removed.
	private var _activeLayerCodes: Set<WeatherService.LayerCode> = []
	
	/// Holds Combine subscriptions to MapsGL events and other Combine subscriptions.
	private var _eventSubscriptions: Set<AnyCancellable> = []
	
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
		
		self.mapView.mapboxMap.styleURI = .dark
		try! self.mapView.mapboxMap.setProjection(.init(name: .mercator)) // Set 2D map projection
		self.mapView.mapboxMap.setCamera(to: .init(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))
		
		#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
			let maximumFPS = Float(UIScreen.main.maximumFramesPerSecond)
			self.mapView.preferredFrameRateRange = .init(minimum: maximumFPS * 2 / 3, maximum: maximumFPS, preferred: maximumFPS)
		#endif // iOS, macCatalyst, tvOS
		
		// Set up the MapsGL ``MapboxMapController``, which will handling adding/removing MapsGL weather layers to the ``MapboxMaps.MapView``.
		let mapController = MapboxMapController(
			map: self.mapView,
			account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
		)
		_mapController = mapController
	}
	
	
	public var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true {
		didSet {
		}
	}
	
	@IBAction public func toggleIsSidebarVisible() {
		self.isSidebarVisible = !(self.isSidebarVisible)
	}
}
