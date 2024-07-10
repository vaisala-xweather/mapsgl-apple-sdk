//
//  FontExtensions.swift
//  Demo
//
//  Created by Slipp Douglas Thompson on 2/13/24.
//

import SwiftUI



internal extension UIFont
{
	static var titleFont: UIFont { UIFont.systemFont(ofSize: 28) }
	static var headerFont: UIFont { UIFont.systemFont(ofSize: 20, weight: .medium) }
	static var cellFont: UIFont { UIFont.systemFont(ofSize: 12, weight: .medium) }
}


internal extension CTFont
{
	static var titleFont: CTFont { UIFont.titleFont }
	static var headerFont: CTFont { UIFont.headerFont }
	static var cellFont: CTFont { UIFont.cellFont }
}

internal extension SwiftUI.Font
{
	static var titleFont: Self { .init(UIFont.titleFont) }
	static var headerFont: Self { .init(UIFont.headerFont) }
	static var cellFont: Self { .init(UIFont.cellFont) }
}
