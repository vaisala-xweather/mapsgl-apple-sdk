//
//  SwiftUIColorExtensions.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/13/24.
//

import SwiftUI
import MapsGLMaps



internal extension SwiftUI.Color
{
	static var backgroundColor: Color { .init(.rgbHex(0x14181A)) }
	static var textColor: Color { .init(.rgbHex(0xFFFFFF)) }
	static var shadowColor: Color { .init(.init(red: 0, green: 0, blue: 0, alpha: 0.15)) }
	static var backgroundHighlightedColor: Color { .init(.rgbHex(0xFFFFFF)) }
	static var textHighlightedColor: Color { .init(.rgbHex(0x333333)) }
	static var closeButtonColor: Color { .init(.rgbHex(0x5D5D5D)) }
	static var cellDividerColor: Color { .init(.rgbHex(0x78858C)) }
}
