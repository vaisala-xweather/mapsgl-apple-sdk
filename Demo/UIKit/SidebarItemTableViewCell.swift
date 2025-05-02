//
//  SidebarItemTableViewCell.swift
//  Demo
//
//  Created by Nicholas Shipes on 5/1/25.
//

import UIKit
import MapsGLMaps

class SidebarItemTableViewCell: UITableViewCell {
    static let reuseIdentifier = "SidebarItemTableViewCell"
    
    var code: WeatherService.LayerCode!

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .cellFont
        label.numberOfLines = 1
        return label
    }()

    // MARK: Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        selectionStyle = .none
        separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)

        updateAppearance()
    }

    // MARK: Configuration
    
    func configure(layer: WeatherLayersModel.Layer, selected: Bool = false) {
        titleLabel.text = layer.title
        code = layer.code
        isSelected = selected
    }

    // MARK: Appearance
    
    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        contentView.backgroundColor = isSelected ? .backgroundHighlightedColor : .backgroundColor
        titleLabel.textColor = isSelected ? .textHighlightedColor : .textColor
    }
}
