//
//  SwiftUIFontExtensions.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/13/24.
//

import SwiftUI



extension SwiftUI.Font
{
	static var titleFont: Font { .custom("Inter", size: 28) }
	static var headerFont: Font { .custom("Inter", size: 20).weight(.medium) }
	static var cellFont: Font { .custom("Inter", size: 12).weight(.medium) }
}
