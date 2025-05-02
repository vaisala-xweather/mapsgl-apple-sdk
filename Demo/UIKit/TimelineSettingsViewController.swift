//
//  Untitled.swift
//  Demo
//
//  Created by Nicholas Shipes on 5/1/25.
//

import UIKit

protocol TimelineSettingsViewControllerDelegate: AnyObject {
    func settingsViewController(_ vc: TimelineSettingsViewController, didUpdateStartDate start: Date)
    func settingsViewController(_ vc: TimelineSettingsViewController, didUpdateEndDate end: Date)
    func settingsViewController(_ vc: TimelineSettingsViewController, didSelectSpeed speed: Double)
    func settingsVCDidDismiss(_ vc: TimelineSettingsViewController)
}

class TimelineSettingsViewController : UIViewController {
    weak var delegate: TimelineSettingsViewControllerDelegate?

    var startDate: Date = Date() {
        didSet { startDateLabel.text = Self.dateTimeFormatter.string(from: startDate) }
    }

    var endDate: Date = Date() {
        didSet { endDateLabel.text = Self.dateTimeFormatter.string(from: endDate) }
    }

    var speedFactor: Double = 1.0 {
        didSet { updateSpeedSelection() }
    }

    // MARK: UI
    private let startDateLabel = UILabel()
    private let endDateLabel = UILabel()
    private var startButtons = [UIButton]()
    private var endButtons = [UIButton]()
    private var speedButtons = [UIButton]()

    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        buildLayout()
    }

    // MARK: Layout
    
    private func buildLayout() {
        // Header
        let titleLabel = UILabel()
        titleLabel.text = "Timeline"
        titleLabel.font = .preferredFont(forTextStyle: .title1)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 12

        // Date Range Labels
        let startRow = rowView(icon: "arrow.left", title: "Start", valueLabel: startDateLabel)
        let endRow   = rowView(icon: "arrow.right", title: "End", valueLabel: endDateLabel)

        // Offset Buttons
        startButtons = makeOffsetButtons(action: #selector(startOffsetTapped(_:)))
        endButtons = makeOffsetButtons(action: #selector(endOffsetTapped(_:)))

        let startButtonStack = buttonRow(with: startButtons)
        let endButtonStack = buttonRow(with: endButtons)

        // Speed Selection
        let speeds: [Double] = [0.25, 0.5, 1.0, 2.0]
        speedButtons = speeds.enumerated().map { idx, speed in
            let button = UIButton(type: .system)
            let title = speed == 1 ? "1x" : String(format: "%.2gx", speed)
            button.setTitle(title, for: .normal)
            button.tag = idx
            button.addTarget(self, action: #selector(speedTapped(_:)), for: .touchUpInside)
            return button
        }
        updateSpeedSelection()
        let speedStack = buttonRow(with: speedButtons)

        // Assemble content view stack
        let content = UIStackView(arrangedSubviews: [
            headerStack,
            sectionLabel("Date Range"),
            startRow, startButtonStack,
            endRow,   endButtonStack,
            footnote("Shift start/end by hour/day intervals."),
            sectionLabel("Animation"),
            rowView(icon: "clock", title: "Speed", valueLabel: nil),
            speedStack
        ])
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.addSubview(content)
        scroll.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: Helpers
    
    private func rowView(icon: String, title: String, valueLabel: UILabel?) -> UIStackView {
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = .backgroundColor
        
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body).bold()
        
        let spacer = UIView()
        let stackItems: [UIView] = [imageView, label, spacer] + (valueLabel.map { [$0] } ?? [])
        
        let stackView = UIStackView(arrangedSubviews: stackItems.compactMap { $0 })
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }

    private func buttonRow(with buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8
        return row
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline).bold()
        return label
    }

    private func footnote(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func makeOffsetButtons(action: Selector) -> [UIButton] {
        let configs: [(String, Calendar.Component, Int)] = [
            ("-1 day", .day, -1),
            ("-1 hour", .hour, -1),
            ("+1 hour", .hour, 1),
            ("+1 day", .day, 1)
        ]
        
        return configs.map { title, comp, val in
            // Map component to int code: .day = 1, .hour = 2
            let compCode: Int
            switch comp {
                case .day: compCode = 1
                case .hour: compCode = 2
                default: compCode = 0
            }
            
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.tag = compCode + (val > 0 ? 100 : 0) // encode component + direction
            button.addTarget(self, action: action, for: .touchUpInside)
            updateButtonStyle(button)
            return button
        }
    }

    // MARK: Actions
    
    @objc private func startOffsetTapped(_ sender: UIButton) {
        adjustDate(&startDate, from: sender)
        delegate?.settingsViewController(self, didUpdateStartDate: startDate)
    }

    @objc private func endOffsetTapped(_ sender: UIButton) {
        adjustDate(&endDate, from: sender)
        delegate?.settingsViewController(self, didUpdateEndDate: endDate)
    }

    private func adjustDate(_ date: inout Date, from button: UIButton) {
        // decode tag into component and direction
        let raw = button.tag
        let compRaw = raw > 100 ? raw - 100 : raw
        let direction = raw > 100 ? 1 : -1
        
        let component: Calendar.Component
        switch compRaw {
            case 1: component = .day
            case 2: component = .hour
            default: return
        }
        date = Calendar.current.date(byAdding: component, value: direction, to: date) ?? date
    }

    @objc private func speedTapped(_ sender: UIButton) {
        let speeds: [Double] = [0.25, 0.5, 1.0, 2.0]
        speedFactor = speeds[sender.tag]
        delegate?.settingsViewController(self, didSelectSpeed: speedFactor)
    }

    private func updateSpeedSelection() {
        let speeds: [Double] = [0.25, 0.5, 1.0, 2.0]
        for (idx, button) in speedButtons.enumerated() {
            let speed = speeds[idx]
            updateButtonStyle(button, selected: speed == speedFactor)
        }
    }
    
    private func updateButtonStyle(_ button: UIButton, selected: Bool = false) {
        button.backgroundColor = selected ? .label : .systemGray5
        button.setTitleColor(selected ? .systemBackground : .label, for: .normal)
        button.layer.cornerRadius = 8
    }

    @objc private func closeTapped() {
        delegate?.settingsVCDidDismiss(self)
        dismiss(animated: true)
    }

    // MARK: Formatter
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy h:mma"
        return f
    }()
}

private extension UIFont {
    func bold() -> UIFont {
        return UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold)!,
                      size: pointSize)
    }
}
