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

class SidebarViewController : UITableViewController {
    var service: WeatherService!
	weak var delegate: SidebarViewControllerDelegate!
    private var needsLayerMetadata = true
	
	override func loadView() {
		super.loadView()
		
        tableView.register(SidebarGroupHeaderTableViewCell.self, forCellReuseIdentifier: SidebarGroupHeaderTableViewCell.reuseIdentifier)
        tableView.register(SidebarItemTableViewCell.self, forCellReuseIdentifier: SidebarItemTableViewCell.reuseIdentifier)
		tableView.rowHeight = UITableView.automaticDimension
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
        self.view.backgroundColor = .backgroundColor
		self.clearsSelectionOnViewWillAppear = false
        
        let headerView = SidebarHeaderView()
        headerView.title = "Layers"
        headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 68)
        headerView.onClose = {
            self.delegate.sidebarDidRequestToClose()
        }
        tableView.tableHeaderView = headerView
	}
	
    override func viewWillAppear(_ animated: Bool) {
        if needsLayerMetadata {
            WeatherLayersModel.store.loadMetadata(service: self.service) {
                self.needsLayerMetadata = false
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
        for code in self.delegate.sidebarSelectedLayerCodes {
            guard let layer = WeatherLayersModel.store.allLayersByCode()[code] else { continue }

            for category in layer.categories {
                guard
                    let section = WeatherLayersModel.Category.allCases.firstIndex(of: category),
                    let row = WeatherLayersModel.store.allLayersByCategory()[category]?.firstIndex(where: { $0.code == code })
                else { continue }

                let indexPath = IndexPath(row: row + 1, section: section)
                self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
	
	private func category(forIndexPath indexPath: IndexPath) -> WeatherLayersModel.Category? {
		guard WeatherLayersModel.Category.allCases.indices.contains(indexPath.section) else {
			return nil
		}
		return WeatherLayersModel.Category.allCases[indexPath.section]
	}
	
	private func layer(forIndexPath indexPath: IndexPath) -> WeatherLayersModel.Layer? {
		guard let category = category(forIndexPath: indexPath),
              let layers = WeatherLayersModel.store.allLayersByCategory()[category] else {
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
        guard let itemCount = WeatherLayersModel.store.allLayersByCategory()[category]?.count else {
			return 0
		}
		return itemCount + 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let category = WeatherLayersModel.Category.allCases[indexPath.section]
		
		if indexPath.row == 0 { // header cell
            let cell = tableView.dequeueReusableCell(withIdentifier: SidebarGroupHeaderTableViewCell.reuseIdentifier, for: indexPath) as! SidebarGroupHeaderTableViewCell
            cell.configure(with: category.title)
			return cell
		} else { // item cell
			let layer = layer(forIndexPath: indexPath)!
            let cell = tableView.dequeueReusableCell(withIdentifier: SidebarItemTableViewCell.reuseIdentifier, for: indexPath) as! SidebarItemTableViewCell
            cell.configure(layer: layer)
            cell.isSelected = delegate.sidebarSelectedLayerCodes.contains(layer.code)
			return cell
		}
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if indexPath.row == 0 { // header cell
			68
		} else { // item cell
			36
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
	
	private func tableView(_ tableView: UITableView, didChangeSelectionOfRowAt indexPath: IndexPath, selected: Bool) {
		if indexPath.row == 0 { // header cell
			return
		} else { // item cell
			let layer = layer(forIndexPath: indexPath)!
            
            if let cell = tableView.cellForRow(at: indexPath) as? SidebarItemTableViewCell {
                cell.isSelected = selected
            }
			
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

// MARK: - SidebarViewControllerDelegate

@objc protocol SidebarViewControllerDelegate {
    var sidebarSelectedLayerCodeValues: Set<WeatherService.LayerCode.RawValue> { get set }
    
	func sidebarDidEnableLayerCode(_ codeValue: WeatherService.LayerCode.RawValue)
	func sidebarDidDisableLayerCode(_ codeValue: WeatherService.LayerCode.RawValue)
    func sidebarDidRequestToClose()
}

extension SidebarViewControllerDelegate {
    var sidebarSelectedLayerCodes: Set<WeatherService.LayerCode> {
        get {
            Set(self.sidebarSelectedLayerCodeValues.compactMap { WeatherService.LayerCode(rawValue: $0) })
        }
        set {
            self.sidebarSelectedLayerCodeValues = Set(newValue.map(\.rawValue))
        }
    }
    
	func sidebarDidEnableLayerCode(_ code: WeatherService.LayerCode) {
		sidebarDidEnableLayerCode(code.rawValue)
	}
    
	func sidebarDidDisableLayerCode(_ code: WeatherService.LayerCode) {
		sidebarDidDisableLayerCode(code.rawValue)
	}
}

// MARK: - SidebarHeaderView

class SidebarHeaderView : UIView {
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    private let titleLabel: UILabel = .init()
    let closeButton: UIButton = .init(type: .system)
    var onClose: (() -> Void)?
    
    // MARK: Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: Setup
    
    private func setupViews() {
        titleLabel.font = .titleFont
        titleLabel.textColor = .textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        let closeImage = UIImage(systemName: "xmark")?.withRenderingMode(.alwaysTemplate)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(closeImage, for: .normal)
        closeButton.tintColor = .closeButtonColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    /// Set the displayed title
    func setTitle(_ text: String) {
        titleLabel.text = text
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
}
