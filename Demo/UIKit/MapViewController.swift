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

class MapViewController : UIViewController, SidebarViewControllerDelegate {
	private let _logger = Logger(type: MapViewController.self)
	
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
    
    private let layersButton = CircleIconButtonView()
    private let currentLocationButton = CircleIconButtonView()
	
//    private func circularIconButton(image: UIImage) -> UIButton {
//        let button = UIButton(type: .system)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.setImage(image, for: .normal)
//        button.tintColor = .white
//        button.backgroundColor = .backgroundColor
//        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
//        button.layer.shadowColor = UIColor.shadowColor.cgColor
//        button.layer.shadowOpacity = 1
//        button.layer.shadowRadius = 8
//        button.layer.shadowOffset = CGSize(width: 0, height: 2)
//        
//        return button
//    }
	
	override func viewDidLoad() {
		super.viewDidLoad()
        
        view.backgroundColor = .systemBackground

        setupMapView()
        setupMapController()
        setupTimelineView()
        setupSidebar()
        
        // add overlay buttons
        layersButton.setImage(UIImage(named: "MapsGL.Stack"), for: .normal)
        layersButton.tintColor = .white
        layersButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(layersButton)
        
        currentLocationButton.setImage(UIImage(named: "MapsGL.Location"), for: .normal)
        currentLocationButton.tintColor = .white
        currentLocationButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(currentLocationButton)
        
        view.bringSubviewToFront(sidebarView)
        
        NSLayoutConstraint.activate([
            layersButton.widthAnchor.constraint(equalToConstant: 44),
            layersButton.heightAnchor.constraint(equalToConstant: 44),
            layersButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            layersButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 44),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 44),
            currentLocationButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
		
        layersButton.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside)
        currentLocationButton.addTarget(self, action: #selector(didTapCurrentLocationButton), for: .touchUpInside)
    }
    
    @objc private func didTapLayersButton() {
        isSidebarVisible.toggle()
    }
    
    @objc private func didTapCurrentLocationButton() {
        Self.locationFinder.findCurrentLocation { location in
            self.mapView.camera.fly(to: .init(center: location.coordinate, zoom: currentLocationZoom))
        } failure: { error in
            print("Failed to get current location: \(error)")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layersButton.layer.cornerRadius = layersButton.bounds.height / 2
        currentLocationButton.layer.cornerRadius = currentLocationButton.bounds.height / 2
    }
	
	override func viewWillAppear(_ animated: Bool) {
		switch isSidebarVisible {
			case true: showSidebar(animate: false)
			case false: hideSidebar(animate: false)
		}
	}
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLayoutForCurrentSizeClass()
    }
    
    private func updateLayoutForCurrentSizeClass() {
        timelineView.horizontalSizeClass = traitCollection.horizontalSizeClass
        
        if traitCollection.horizontalSizeClass == .regular {
            NSLayoutConstraint.deactivate(stackedConstraints)
            NSLayoutConstraint.activate(overlayConstraints)
            
            timelineView.layer.cornerRadius = 12
            timelineView.layer.masksToBounds = false
            timelineView.layer.shadowColor = UIColor.black.cgColor
            timelineView.layer.shadowOpacity = 0.2
            timelineView.layer.shadowOffset = CGSize(width: 0, height: 2)
            timelineView.layer.shadowRadius = 4
        } else {
            NSLayoutConstraint.deactivate(overlayConstraints)
            NSLayoutConstraint.activate(stackedConstraints)
            
            timelineView.layer.cornerRadius = 0
            timelineView.layer.shadowOpacity = 0
        }
    }
    
    private var overlayConstraints: [NSLayoutConstraint] = []
    private var stackedConstraints: [NSLayoutConstraint] = []
    
    // MARK: Map View
    
    private var mapView: MapboxMaps.MapView!
    
    /// MapsGL's controller that manages adding/removing MapsGL weather layers to/from the ``MapboxMaps.MapView``.
    private var mapController: MapboxMapController!
    
    private func setupMapView() {
        let options = MapInitOptions(
            cameraOptions: CameraOptions(
                center: .geographicCenterOfContiguousUSA,
                zoom: initialZoom
            ),
            styleURI: .streets
        )
        mapView = MapView(frame: .zero, mapInitOptions: options)
        view.addSubview(mapView)
        
        mapView.mapboxMap.styleURI = (self.traitCollection.userInterfaceStyle == .dark) ? .dark : .light
        try! mapView.mapboxMap.setProjection(.init(name: .mercator)) // Set 2D map projection
        mapView.mapboxMap.setCamera(to: .init(center: .geographicCenterOfContiguousUSA, zoom: initialZoom))
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
            let maximumFPS = Float(UIScreen.main.maximumFramesPerSecond)
            mapView.preferredFrameRateRange = .init(minimum: maximumFPS * 2 / 3, maximum: maximumFPS, preferred: maximumFPS)
        #endif // iOS, macCatalyst, tvOS
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupMapController() {
        // Set up the MapsGL ``MapboxMapController``, which will handling adding/removing MapsGL weather layers to the ``MapboxMaps.MapView``.
        mapController = MapboxMapController(
            map: mapView,
            account: XweatherAccount(id: AccessKeys.shared.xweatherClientID, secret: AccessKeys.shared.xweatherClientSecret)
        )

        // loading indicators
        mapController.onLoadStart
            .observe { [weak self] in
                DispatchQueue.main.async {
                    self?.timelineView.isLoading = true
                }
            }
            .store(in: &_eventSubscriptions)

        mapController.onLoadComplete
            .observe { [weak self] in
                DispatchQueue.main.async {
                    self?.timelineView.isLoading = false
                }
            }
            .store(in: &_eventSubscriptions)

        // timeline wiring
        let timeline = mapController.timeline
        timeline.startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        timeline.endDate = Date()

        timeline.onAdvance.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.timelineView.timelinePosition = timeline.position
                    self.timelineView.currentDate = timeline.currentDate
                }
            }
            .store(in: &_eventSubscriptions)

        // Once the map has completed initial load…
        mapController.subscribe(to: MapEvents.Load.self) { _ in
            // Start listening to Combine-provided change events of the `dataModel`'s selected layers.
            self.dataModel.$selectedLayerCodes.sink { selectedLayerCodes in
                // Remove any layers that are no longer selected.
                let layerCodesToRemove = self._activeLayerCodes.subtracting(selectedLayerCodes)
                if !layerCodesToRemove.isEmpty {
                    self._logger.debug("Removing layers: \(layerCodesToRemove)")
                    
                    for code in layerCodesToRemove {
                        self.mapController.removeWeatherLayer(forCode: code)
                    }
                }
                
                // Construct the configuration for and add any layers that are newly selected.
                let layerCodesToAdd = selectedLayerCodes.subtracting(self._activeLayerCodes)
                if !layerCodesToAdd.isEmpty {
                    self._logger.debug("Adding layers: \(layerCodesToAdd)")
                    
                    let roadLayerId = self.mapController.map.firstLayer(matching: /^(?:tunnel|road|bridge)-/)?.id
                    for code in layerCodesToAdd {
                        do {
                            let layer = WeatherLayersModel.allLayersByCode[code]!
                            try self.mapController.addWeatherLayer(config: layer.makeConfiguration(self.mapController.service), beforeId: roadLayerId)
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
    
    // MARK: Timeline View
    
    var timelineView: TimelineView!
    
    private func setupTimelineView() {
        timelineView = TimelineView()
        timelineView.delegate = self
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timelineView)

        // Overlay (iPad / regular width)
        overlayConstraints = [
            timelineView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            timelineView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            timelineView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ]

        // Stacked (iPhone / compact width)
        stackedConstraints = [
            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timelineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]

        // (height is intrinsic from its content)
        updateLayoutForCurrentSizeClass()
    }
	
	// MARK: Sidebar View
	
    var sidebarView: UIView!
	var sidebarViewLeftConstraint: NSLayoutConstraint!
	
	public var isSidebarVisible = (UIDevice.current.userInterfaceIdiom == .phone) ? false : true {
		didSet {
			switch (oldValue, self.isSidebarVisible) {
				case (false, true): showSidebar()
				case (true, false): hideSidebar()
				default: return
			}
		}
	}
    
    private func setupSidebar() {
        // Create sidebar container
        sidebarView = UIView()
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebarView)

        // Embed the SidebarViewController
        let sidebarVC = SidebarViewController()
        sidebarVC.delegate = self
        addChild(sidebarVC)
        sidebarVC.view.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(sidebarVC.view)
        sidebarVC.didMove(toParent: self)

        // Sidebar width
        let sidebarWidth: CGFloat = 300

        // Leading constraint for show/hide
        sidebarViewLeftConstraint = sidebarView.leadingAnchor.constraint(
            equalTo: view.leadingAnchor,
            constant: isSidebarVisible ? 0 : -sidebarWidth
        )

        NSLayoutConstraint.activate([
            sidebarViewLeftConstraint,
            sidebarView.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth),

            // Pin sidebarVC's view inside container
            sidebarVC.view.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            sidebarVC.view.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarVC.view.topAnchor.constraint(equalTo: sidebarView.topAnchor),
            sidebarVC.view.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor),
        ])
    }
	
    public func showSidebar() { showSidebar(animate: true) }
	public func showSidebar(animate: Bool = true) {
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
	
	public func hideSidebar() { hideSidebar(animate: true) }
	public func hideSidebar(animate: Bool = true) {
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
	
	public func toggleIsSidebarVisible() {
		self.isSidebarVisible = !(self.isSidebarVisible)
	}
	
	// MARK: Current Location
	
	private static let locationFinder = LocationFinder()
	
	public func flyToCurrentLocation() {
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
    
    func sidebarDidRequestToClose() {
        toggleIsSidebarVisible()
    }
}

extension MapViewController : TimelineViewDelegate {
    func timelineView(_ view: TimelineView, didChangePosition position: Double) {
        mapController.timeline.goTo(position: position)
    }

    func timelineView(_ view: TimelineView, didTogglePlay isPlaying: Bool) {
        let t = mapController.timeline
        isPlaying ? t.play() : t.stop()
    }

    func timelineViewDidTapSettings(_ view: TimelineView) {
        let settingsVC = TimelineSettingsViewController()
        settingsVC.delegate = self
        settingsVC.startDate = mapController.timeline.startDate
        settingsVC.endDate = mapController.timeline.endDate
        settingsVC.speedFactor = mapController.timeline.timeScale
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: show as popover
            settingsVC.modalPresentationStyle = .popover
            if let pop = settingsVC.popoverPresentationController {
                pop.sourceView = view
                pop.sourceRect = view.bounds
                pop.permittedArrowDirections = .any
            }
        } else {
            // iPhone: show as sheet with a medium detent
            settingsVC.modalPresentationStyle = .pageSheet
            if let sheet = settingsVC.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = false
            }
        }
        
        present(settingsVC, animated: true)
    }
}

extension MapViewController : TimelineSettingsViewControllerDelegate {
    func settingsViewController(_ vc: TimelineSettingsViewController, didUpdateStartDate start: Date) {
        mapController.timeline.startDate = start
    }
    
    func settingsViewController(_ vc: TimelineSettingsViewController, didUpdateEndDate end: Date) {
        mapController.timeline.endDate = end
    }
    
    func settingsViewController(_ vc: TimelineSettingsViewController, didSelectSpeed speed: Double) {
        mapController.timeline.timeScale = speed
        timelineView.isPlaying = false
    }
    
    func settingsVCDidDismiss(_ vc: TimelineSettingsViewController) {
        // nothing special
    }
}
