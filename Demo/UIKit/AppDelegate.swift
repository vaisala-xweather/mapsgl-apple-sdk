//
//  AppDelegate.swift
//  DemoUIKit
//
//  Created by Slipp Douglas Thompson on 7/10/24.
//

import UIKit
import MapboxMaps

@main
class AppDelegate : UIResponder, UIApplicationDelegate {
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		MapboxOptions.accessToken = AccessKeys.shared.mapboxAccessToken
		
		return true
	}
	
	// MARK: UISceneSession Lifecycle
	
	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}
	
	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
