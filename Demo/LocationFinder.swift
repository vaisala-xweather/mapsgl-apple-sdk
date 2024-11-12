//
//  LocationFinder.swift
//  Demo
//
//  Created by Slipp Thompson on 11/8/24.
//

import CoreLocation



/// Finds the current low-accuracy location of the user on-demand, with location updating only active until the callback is called.
final class LocationFinder : NSObject, CLLocationManagerDelegate
{
	private lazy var _locationManager: CLLocationManager = {
		var manager = CLLocationManager()
		manager.delegate = self
		manager.distanceFilter = CLLocationDistanceMax
		manager.desiredAccuracy = kCLLocationAccuracyReduced
		return manager
	}()
	
	private var _completions: [((Result<CLLocation, Error>) -> Void)] = []
	
	func findCurrentLocation(_ completion: @escaping (Result<CLLocation, Error>) -> Void)
	{
		print("findCurrentLocation: _locationManager.authorizationStatus: \(_locationManager.authorizationStatus)")
		_completions.append(completion)
		if case .notDetermined = _locationManager.authorizationStatus {
			_locationManager.requestWhenInUseAuthorization()
			// continues to `locationManagerDidChangeAuthorization(_:)`
		}
		else {
			_locationManager.requestLocation()
			// continues to `locationManager(_,didUpdateLocations:)` or `locationManager(_:,didFailWithError:)`
		}
	}
	
	
	// MARK: CLLocationManagerDelegate callbacks
	
	func locationManagerDidChangeAuthorization(_ _: CLLocationManager) {
		print("locationManagerDidChangeAuthorization: _locationManager.authorizationStatus: \(_locationManager.authorizationStatus)")
		if [.restricted, .denied].contains(_locationManager.authorizationStatus) {
			_completions.forEach { $0(.failure(.notAuthorized)) }
			_completions = []
		}
		// `.notDetermined` is ignored, since `locationManagerDidChangeAuthorization(…)` will fire immediately when `requestLocation()` is called, then again once the auth pop-up has been tapped on
		else if [.authorizedWhenInUse, .authorizedAlways].contains(_locationManager.authorizationStatus) {
			_locationManager.requestLocation()
			// continues to `locationManager(_,didUpdateLocations:)` or `locationManager(_:,didFailWithError:)`
		}
	}
	
	func locationManager(_ _: CLLocationManager, didUpdateLocations locations: [CLLocation])
	{
		_completions.forEach { $0(.success(locations.last!)) }
		_completions = []
	}
	
	func locationManager(_ _: CLLocationManager, didFailWithError error: any Swift.Error)
	{
		let clError = CLError(CLError.Code(rawValue: (error as NSError).code)!)
		_completions.forEach { $0(.failure(.coreLocation(clError))) }
		_completions = []
	}
	
	enum Error : LocalizedError {
		case notAuthorized
		case coreLocation(CLError)
		case unknown
		
		var errorDescription: String? {
			switch self {
				case .notAuthorized:
					"Access to your location is not authorized."
				case .coreLocation(let clError):
					switch clError.code {
						case .locationUnknown: "Your location could not be determined for an unknown reason."
						case .denied: "Access to your location is not authorized."
						case .promptDeclined: "Access to your location was declined."
						case .network: "Network issues prevented a location update."
						default: "An error occurred while retrieving your location."
					}
				case .unknown:
					"An unknown error occurred."
			}
		}
	}
}



extension LocationFinder
{
	/// Convenience variant method for dual success/failure closures.
	func findCurrentLocation(_ locationCompletion: @escaping (CLLocation) -> Void, failure failureCompletion: @escaping (Error) -> Void) {
		findCurrentLocation { result in
			switch result {
				case .success(let location):
					locationCompletion(location)
				case .failure(let error):
					failureCompletion(error)
			}
		}
	}
}
