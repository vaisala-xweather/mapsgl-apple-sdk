//
//	SidebarViewController.swift
//	Demo - UIKit
//
//	Created by Slipp Douglas Thompson on 7/10/24.
//

import UIKit
import OSLog
import MapsGLMaps



fileprivate let logger = Logger(type: SidebarViewController.self)



class SidebarViewController : UITableViewController
{
	@IBInspectable var headerCellReuseIdentifier: String!
	@IBInspectable var itemCellReuseIdentifier: String!
	
	@IBOutlet weak var delegate: SidebarViewControllerDelegate!
	
	
	override func loadView() {
		super.loadView()
		
		self.tableView.rowHeight = UITableView.automaticDimension
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.clearsSelectionOnViewWillAppear = false
	}
	
	override func viewWillAppear(_ animated: Bool)
	{
		for code in self.delegate.sidebarSelectedLayerCodes {
			let layer = WeatherLayersModel.allLayersByCode[code]!
			let categoryIndex = WeatherLayersModel.Category.allCases.firstIndex(of: layer.category)!
			let layerIndex = WeatherLayersModel.allLayersByCategory[layer.category]!.firstIndex { $0.code == code }!
			let indexPath = IndexPath(row: layerIndex + 1, section: categoryIndex)
			self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
		}
	}
	
	
	private func category(forIndexPath indexPath: IndexPath) -> WeatherLayersModel.Category?
	{
		guard WeatherLayersModel.Category.allCases.indices.contains(indexPath.section) else {
			return nil
		}
		return WeatherLayersModel.Category.allCases[indexPath.section]
	}
	
	private func layer(forIndexPath indexPath: IndexPath) -> WeatherLayersModel.Layer?
	{
		guard let category = category(forIndexPath: indexPath),
			let layers = WeatherLayersModel.allLayersByCategory[category] else {
			return nil
		}
		
		if indexPath.row == 0 { // header cell
			return nil
		} else { // item cell
			let layerIndex = indexPath.row - 1
			guard layers.indices.contains(layerIndex) else {
				return nil
			}
			return layers[layerIndex]
		}
	}
	
	
	// MARK: UITableViewDataSource Conformance
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		WeatherLayersModel.Category.allCases.count
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let category = WeatherLayersModel.Category.allCases[section]
		guard let itemCount = WeatherLayersModel.allLayersByCategory[category]?.count else {
			return 0
		}
		return itemCount + 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let category = WeatherLayersModel.Category.allCases[indexPath.section]
		
		if indexPath.row == 0 { // header cell
			let cell = tableView.dequeueReusableCell(withIdentifier: self.headerCellReuseIdentifier, for: indexPath) as! SidebarGroupHeaderTableViewCell
			cell.label.text = category.title
			return cell
		}
		else { // item cell
			let layer = layer(forIndexPath: indexPath)!
			
			let cell = tableView.dequeueReusableCell(withIdentifier: self.itemCellReuseIdentifier, for: indexPath) as! SidebarItemTableViewCell
			cell.label.text = layer.title
			cell.code = layer.code
			return cell
		}
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if indexPath.row == 0 { // header cell
			68
		} else { // item cell
			32
		}
	}
	
	
	// MARK: UITableViewDelegate Conformance
	
	override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		if indexPath.row == 0 { // header cell
			nil
		} else { // item cell
			indexPath
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		self.tableView(tableView, didChangeSelectionOfRowAt: indexPath, selected: true)
	}
	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		self.tableView(tableView, didChangeSelectionOfRowAt: indexPath, selected: false)
	}
	
	private func tableView(_ tableView: UITableView, didChangeSelectionOfRowAt indexPath: IndexPath, selected: Bool)
	{
		if indexPath.row == 0 { // header cell
			return
		} else { // item cell
			let layer = layer(forIndexPath: indexPath)!
			
			if selected {
				self.delegate.sidebarSelectedLayerCodes.update(with: layer.code)
				self.delegate.sidebarDidEnableLayerCode(layer.code)
			} else {
				self.delegate.sidebarSelectedLayerCodes.remove(layer.code)
				self.delegate.sidebarDidDisableLayerCode(layer.code)
			}
		}
	}
}



@objc protocol SidebarViewControllerDelegate
{
	func sidebarDidEnableLayerCode(_ codeValue: WeatherService.LayerCode.RawValue)
	func sidebarDidDisableLayerCode(_ codeValue: WeatherService.LayerCode.RawValue)
	
	var sidebarSelectedLayerCodeValues: Set<WeatherService.LayerCode.RawValue> { get set }
}

extension SidebarViewControllerDelegate
{
	func sidebarDidEnableLayerCode(_ code: WeatherService.LayerCode) {
		sidebarDidEnableLayerCode(code.rawValue)
	}
	func sidebarDidDisableLayerCode(_ code: WeatherService.LayerCode) {
		sidebarDidDisableLayerCode(code.rawValue)
	}
	
	var sidebarSelectedLayerCodes: Set<WeatherService.LayerCode> {
		get { Set(self.sidebarSelectedLayerCodeValues.compactMap { WeatherService.LayerCode(rawValue: $0) }) }
		set { self.sidebarSelectedLayerCodeValues = Set(newValue.map(\.rawValue)) }
	}
}
