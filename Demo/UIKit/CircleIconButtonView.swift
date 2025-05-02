//
//  CircleButtonView.swift
//  Demo - UIKit
//
//  Created by Slipp Douglas Thompson on 7/10/24.
//

import UIKit

class CircleIconButtonView : UIButton {	
	/// Ensure the default UIButton `backgroundColor` has no effect (and doesn't draw a square background).
	override var backgroundColor: UIColor? {
		get { return .clear }
		set { super.backgroundColor = .clear }
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}
	
	private func setup() {
		self.backgroundColor = .backgroundColor
		self.tintColor = .textColor
		
		self.layer.shadowColor = .shadowColor
		self.layer.shadowOpacity = 1.0
		self.layer.shadowRadius = 8
		self.layer.shadowOffset = .init(width: 0, height: +2)
		self.layer.shadowPath = UIBezierPath(ovalIn: self.bounds).cgPath
		self.layer.shouldRasterize = true
		#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
			self.layer.rasterizationScale = UIScreen.main.scale
		#endif // iOS, macCatalyst, tvOS
	}
	
	override func draw(_ rect: CGRect) {
		UIColor.backgroundColor.setFill()
		UIBezierPath(ovalIn: rect).fill()
		
		super.draw(rect)
	}
}
