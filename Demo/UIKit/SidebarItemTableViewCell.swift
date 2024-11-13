//
//  SidebarItemTableViewCell.swift
//  Demo - UIKit
//
//  Created by Slipp Douglas Thompson on 7/31/24.
//

import UIKit
import MapsGLMaps



class SidebarItemTableViewCell : UITableViewCell
{
	@IBOutlet var label: UILabel!
	var code: WeatherService.LayerCode!
	
	@IBInspectable var highlightedBackgroundColor: UIColor = .clear
	@IBInspectable var normalTextColor: UIColor = .lightText
	@IBInspectable var highlightedTextColor: UIColor = .darkText
	
	
	override func awakeFromNib()
	{
		super.awakeFromNib()
		
		// Initialization code
		
		let backgroundColorView = UIView()
		backgroundColorView.backgroundColor = highlightedBackgroundColor
		self.selectedBackgroundView = backgroundColorView
	}

	override func setSelected(_ selected: Bool, animated: Bool)
	{
		super.setSelected(selected, animated: animated)
		
		self.label.textColor = switch selected { 
			case false: self.normalTextColor
			case true: self.highlightedTextColor
		}
	}
}
