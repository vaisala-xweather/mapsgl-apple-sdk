//
//  ViewController.swift
//  DemoUIKit
//
//  Created by Slipp Douglas Thompson on 7/10/24.
//

import Combine
import UIKit
import OSLog
import MapboxMaps
import MapsGLMaps
import MapsGLMapbox



fileprivate let initialZoom: Double = 2.75
fileprivate let currentLocationZoom: Double = 4.0



class MapViewController : UIViewController, SidebarViewControllerDelegate
{
	private let _logger = Logger(type: MapViewController.self)
	
	
	@IBOutlet private var mapView: MapboxMaps.MapView!
	
	/// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the ``MapboxMaps.MapView``.
	private var _mapController: MapboxMapController!
	
	var dataModel: WeatherLayersModel = .init(
		selectedLayerCodes: [ .windParticles ]
	)
	
	/// Stores the active layer codes that we've already handled by adding/removing layers to/from the ``mapController``.
	/// Used for change-checking in comparison to the ``dataModel.selectedLayerCodes`` to determine if there are new layers that need to be added, or old layers that need to be removed.
	private var _activeLayerCodes: Set<WeatherService.LayerCode> = []
	
	/// SidebarViewControllerDelegate Conformance
	var sidebarSelectedLayerCodeValues: Set<MapsGLMaps.WeatherService.LayerCode.RawValue> {
		get { Set(self.dataModel.selectedLayerCodes.map(\.rawValue)) }
		set { self.dataModel.selectedLayerCodes = Set(newValue.compactMap { WeatherService.LayerCode(rawValue: $0) }) }
	}
	
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
		
		// Once the map has completed initial load…
		mapController.subscribe(to: MapEvents.Load.self) { _ in
			// Start listening to Combine-provided change events of the `dataModel`'s selected layers.
			self.dataModel.$selectedLayerCodes.sink { selectedLayerCodes in
				// Remove any layers that are no longer selected.
				let layerCodesToRemove = self._activeLayerCodes.subtracting(selectedLayerCodes)
				if !layerCodesToRemove.isEmpty {
					self._logger.debug("Removing layers: \(layerCodesToRemove)")
					
					for code in layerCodesToRemove {
						mapController.removeWeatherLayer(forCode: code)
					}
				}
				
				// Construct the configuration for and add any layers that are newly selected.
				let layerCodesToAdd = selectedLayerCodes.subtracting(self._activeLayerCodes)
				if !layerCodesToAdd.isEmpty {
					self._logger.debug("Adding layers: \(layerCodesToAdd)")
					
					let roadLayerId = mapController.map.firstLayer(matching: /^(?:tunnel|road|bridge)-/)?.id
					for code in layerCodesToAdd {
						do {
							let layer = WeatherLayersModel.allLayersByCode[code]!
							try mapController.addWeatherLayer(config: layer.makeConfiguration(mapController.service), beforeId: roadLayerId)
						} catch {
							self._logger.error("Failed to add weather layer: \(error)")
						}
					}
				}
				
				self._activeLayerCodes = selectedLayerCodes
			}
			.store(in: &self._eventSubscriptions)
		}
		.store(in: &_eventSubscriptions)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		switch isSidebarVisible {
			case true: showSidebar(animate: false)
			case false: hideSidebar(animate: false)
		}
	}
	
	
	// MARK: Sidebar View
	
	@IBOutlet var sidebarView: UIView!
	@IBOutlet var sidebarViewLeftConstraint: NSLayoutConstraint!
	
	public var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true {
		didSet {
			switch (oldValue, self.isSidebarVisible) {
				case (false, true): showSidebar()
				case (true, false): hideSidebar()
				default: return
			}
		}
	}
	
	
	@IBAction public func showSidebar() { showSidebar(animate: true) }
	public func showSidebar(animate: Bool = true)
	{
		let animationCommands = {
			self.sidebarView.isHidden = false
			self.sidebarViewLeftConstraint.constant = 0.0
			
			self.sidebarView.superview!.layoutIfNeeded()
		}
		
		self.sidebarView.superview!.layoutIfNeeded()
		if animate {
			UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseInOut,
				animations: animationCommands
			)
		} else {
			animationCommands()
		}
	}
	
	@IBAction public func hideSidebar() { hideSidebar(animate: true) }
	public func hideSidebar(animate: Bool = true)
	{
		let animationCommands = {
			self.sidebarViewLeftConstraint.constant = -(self.sidebarView.frame.size.width)
			
			self.sidebarView.superview!.layoutIfNeeded()
		}
		let animationFinishedCommands = { (finished: Bool) in
			self.sidebarView.isHidden = true
		}
		
		self.sidebarView.superview!.layoutIfNeeded()
		if animate {
			UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseInOut,
				animations: animationCommands, completion: animationFinishedCommands
			)
		} else {
			animationCommands()
			animationFinishedCommands(true)
		}
	}
	
	@IBAction public func toggleIsSidebarVisible() {
		self.isSidebarVisible = !(self.isSidebarVisible)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?)
	{
		if let sidebarViewController = segue.destination as? SidebarViewController {
			sidebarViewController.delegate = self
		}
	}
	
	
	// MARK: Current Location
	
	private static let locationFinder = LocationFinder()
	
	@IBAction public func flyToCurrentLocation() {
		Self.locationFinder.findCurrentLocation { location in
			self.mapView.camera.fly(to: .init(center: location.coordinate, zoom: currentLocationZoom))
		} failure: { error in
			let alert = UIAlertController(title: error.errorDescription, message: nil, preferredStyle: .alert)
			alert.addAction(.init(title: "OK", style: .default))
			self.present(alert, animated: true)
		}
	}
	
	
	// MARK: SidebarViewControllerDelegate Conformance
	
	func sidebarDidEnableLayerCode(_ codeValue: MapsGLMaps.WeatherService.LayerCode.RawValue) {}
	func sidebarDidDisableLayerCode(_ codeValue: MapsGLMaps.WeatherService.LayerCode.RawValue) {}
}
