//
//  ColorExtensions.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/13/24.
//

import SwiftUI
import MapsGLMaps



internal extension CGColor
{
	static var backgroundColor: CGColor { .rgbHex(0x14181A) }
	static var textColor: CGColor { .rgbHex(0xFFFFFF) }
	static var shadowColor: CGColor { .init(red: 0, green: 0, blue: 0, alpha: 0.30) }
	static var backgroundHighlightedColor: CGColor { .rgbHex(0xFFFFFF) }
	static var textHighlightedColor: CGColor { .rgbHex(0x333333) }
	static var closeButtonColor: CGColor { .rgbHex(0x5D5D5D) }
	static var cellDividerColor: CGColor { .rgbHex(0x78858C) }
}


internal extension SwiftUI.Color
{
	static var backgroundColor: Self { .init(cgColor: .backgroundColor) }
	static var textColor: Self { .init(cgColor: .textColor) }
	static var shadowColor: Self { .init(cgColor: .shadowColor) }
	static var backgroundHighlightedColor: Self { .init(cgColor: .backgroundHighlightedColor) }
	static var textHighlightedColor: Self { .init(cgColor: .textHighlightedColor) }
	static var closeButtonColor: Self { .init(cgColor: .closeButtonColor) }
	static var cellDividerColor: Self { .init(cgColor: .cellDividerColor) }
}

internal extension UIColor
{
	static var backgroundColor: Self { .init(cgColor: .backgroundColor) }
	static var textColor: Self { .init(cgColor: .textColor) }
	static var shadowColor: Self { .init(cgColor: .shadowColor) }
	static var backgroundHighlightedColor: Self { .init(cgColor: .backgroundHighlightedColor) }
	static var textHighlightedColor: Self { .init(cgColor: .textHighlightedColor) }
	static var closeButtonColor: Self { .init(cgColor: .closeButtonColor) }
	static var cellDividerColor: Self { .init(cgColor: .cellDividerColor) }
}


