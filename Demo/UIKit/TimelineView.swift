//
//  TimelineView.swift
//  Demo
//
//  Created by Nicholas Shipes on 5/1/25.
//

import UIKit

protocol TimelineViewDelegate: AnyObject {
    func timelineView(_ view: TimelineView, didChangePosition position: Double)
    func timelineView(_ view: TimelineView, didTogglePlay isPlaying: Bool)
    func timelineViewDidTapSettings(_ view: TimelineView)
}

class TimelineView: UIView {
    // MARK: Public API
    weak var delegate: TimelineViewDelegate?

    var timelinePosition: Double {
        get { Double(slider.value) }
        set { slider.setValue(Float(newValue), animated: false) }
    }

    var isPlaying: Bool = false {
        didSet {
            let imageName = isPlaying ? "pause.fill" : "play.fill"
            playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
        }
    }

    var currentDate: Date = .now {
        didSet {
            timeLabel.text = Self.timeFormatter.string(from: currentDate)
            dateLabel.text = Self.dateFormatter.string(from: currentDate)
        }
    }

    var isLoading: Bool = false {
        didSet {
            isLoading
                ? activityIndicator.startAnimating()
                : activityIndicator.stopAnimating()
        }
    }
    
    var horizontalSizeClass: UIUserInterfaceSizeClass = .unspecified {
        didSet {
            if horizontalSizeClass == .regular {
                NSLayoutConstraint.deactivate(stackedConstraints)
                NSLayoutConstraint.activate(overlayConstraints)
            } else {
                NSLayoutConstraint.deactivate(overlayConstraints)
                NSLayoutConstraint.activate(stackedConstraints)
            }
        }
    }
    
    private var overlayConstraints: [NSLayoutConstraint] = []
    private var stackedConstraints: [NSLayoutConstraint] = []
    
    private let slider = UISlider()
    private let timeLabel = UILabel()
    private let dateLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let playPauseButton = CircleIconButtonView()
    private let settingsButton = CircleIconButtonView()

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
        backgroundColor = .backgroundColor
        overrideUserInterfaceStyle = .dark
        
        // Slider
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)

        // Labels
        timeLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        dateLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        dateLabel.textColor = .secondaryLabel

        // Activity Indicator
        activityIndicator.hidesWhenStopped = true

        // Play/Pause Button
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .selected)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        // Settings Button
        settingsButton.setImage(UIImage(named: "MapsGL.Settings"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        // Layout with StackViews
        let labelsStack = UIStackView(arrangedSubviews: [timeLabel, dateLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 2

        let controlsStack = UIStackView(arrangedSubviews: [playPauseButton, settingsButton])
        controlsStack.axis = .horizontal
        controlsStack.spacing = 12

        let hStack = UIStackView(arrangedSubviews: [
            labelsStack,
            UIView(),     // spacer
            activityIndicator,
            controlsStack
        ])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 8

        let vStack = UIStackView(arrangedSubviews: [slider, hStack])
        vStack.axis = .vertical
        vStack.spacing = 12
        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)
        
        let padding: CGFloat = 16
        
        NSLayoutConstraint.activate([
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
            vStack.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            vStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            vStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding)
        ])
        
        stackedConstraints = [
            vStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ]
        
        overlayConstraints = [
            vStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ]

        horizontalSizeClass = .compact
        currentDate = .now
        isPlaying = false
        isLoading = false
    }

    // MARK: Actions
    
    @objc private func sliderChanged(_ sender: UISlider) {
        delegate?.timelineView(self, didChangePosition: Double(sender.value))
    }

    @objc private func playPauseTapped() {
        isPlaying.toggle()
        delegate?.timelineView(self, didTogglePlay: isPlaying)
    }

    @objc private func settingsTapped() {
        delegate?.timelineViewDidTapSettings(self)
    }

    // MARK: Formatters
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E, MMM d"
        return f
    }()
}
