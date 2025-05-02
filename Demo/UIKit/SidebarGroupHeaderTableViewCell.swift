//
//  GroupHeaderTableViewCell.swift
//  Demo
//
//  Created by Nicholas Shipes on 5/1/25.
//

import UIKit

class SidebarGroupHeaderTableViewCell: UITableViewCell {
    static let reuseIdentifier = "GroupHeaderTableViewCell"

    private let headerLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.font = .headerFont
        label.textColor = .textColor
        
        return label
    }()

    // MARK: Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(headerLabel)
        
        // Paddings: top 28, leading+trailing 20, bottom 12; fixed height 28
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        // Remove default background separators
        backgroundColor = .backgroundColor
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Configuration

    func configure(with title: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 20
        
        headerLabel.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.headerFont,
                .foregroundColor: UIColor.textColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}
