//
//  AccessKeys.swift
//  MapsGL Demo
//
//  Created by Nicholas Shipes on 11/8/23.
//

import Foundation



struct AccessKeys : Decodable
{
	let xweatherClientID: String
	let xweatherClientSecret: String
	let mapboxAccessToken: String
	
	enum CodingKeys : String, CodingKey {
		case xweatherClientID = "XweatherClientID"
		case xweatherClientSecret = "XweatherClientSecret"
		case mapboxAccessToken = "MapboxAccessToken"
	}
}


fileprivate var _sharedAccessKeys = AccessKeys.loadFromPlist()

extension AccessKeys
{
	/// The default-named `AccessKeys.plist` from the main `Bundle`.
	static var shared: AccessKeys { _sharedAccessKeys }
	
	static func loadFromPlist(name: String = "AccessKeys") -> Self
	{
		let fileName = "\(name).plist"
		guard let url = Bundle.main.url(forResource: name, withExtension: "plist") else {
			fatalError("Couldn't find file '\(fileName)'.")
		}
		guard let data = try? Data(contentsOf: url) else {
			fatalError("Couldn't load file '\(fileName)'.")
		}
		
		do {
			return try PropertyListDecoder().decode(Self.self, from: data)
		}
		catch DecodingError.keyNotFound(let key, _) {
			fatalError("Couldn't find required key '\(key.stringValue)' in '\(fileName)'.")
		}
		catch DecodingError.valueNotFound(_, let context) {
			fatalError("Missing value for key '\(context.codingPath)' in '\(fileName)'.")
		}
		catch {
			fatalError("Couldn't read file '\(name).plist': \(error).")
		}
	}
}
