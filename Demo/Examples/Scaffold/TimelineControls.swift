//
//  TimelineControls.swift
//  Demo
//

import SwiftUI

/// The demo's animation transport: a scrub bar, the time it is showing, and the
/// controls for playing it.
///
/// The readout is the one number on screen, so it takes the data display role —
/// Light, tabular, tracked like a heading — and the date under it is an overline.
struct TimelineView: View {
    @Binding var timelinePosition: Double
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var currentDate: Date
    @Binding var selectedSpeed: Double
    @Binding var isPlaying: Bool
    @Binding var isLoading: Bool
    @Binding var isPreloadEnabled: Bool

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: XWSpace.x3) {
            Slider(value: $timelinePosition, in: 0...1)
                .tint(XWColor.accent)
                .padding(.horizontal, XWSpace.x4)

            HStack(spacing: XWSpace.x3) {
                VStack(alignment: .leading, spacing: XWSpace.x1) {
                    Text(currentDate, formatter: Self.timeFormatter)
                        .xwDataDisplay()
                        .foregroundStyle(XWColor.textPrimary)
                    Text(currentDate, formatter: Self.dateFormatter)
                        .xwOverline()
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                HStack(spacing: XWSpace.x3) {
                    CircularIconButton(systemName: isPlaying ? "pause.fill" : "play.fill") {
                        isPlaying.toggle()
                    }
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")

                    CircularIconButton(systemName: "slider.horizontal.3") {
                        showSettings = true
                    }
                    .accessibilityLabel("Timeline settings")
                }
            }
            .padding(.horizontal, XWSpace.x4)
        }
        .padding(.vertical, XWSpace.x2)
        .popover(isPresented: $showSettings, attachmentAnchor: .point(.center), arrowEdge: .bottom) {
            let settingsView = TimelineSettingsView(
                startDate: $startDate,
                endDate: $endDate,
                selectedSpeed: $selectedSpeed,
                isPreloadEnabled: $isPreloadEnabled
            )
            .presentationDetents([.medium])

            if #available(iOS 16.4, *) {
                settingsView
                    .presentationBackground(XWColor.backgroundPrimary)
            } else {
                settingsView
            }
        }
    }

    // MARK: Date Formatters

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

/// The timeline's settings: the range it covers, how fast it plays, and whether it
/// preloads.
///
/// Laid out the way the design system lays out a technical page — an overline naming
/// each section, a labelled row stating the current value, and the controls that
/// change it underneath.
struct TimelineSettingsView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedSpeed: Double
    @Binding var isPreloadEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    private static let speeds: [Double] = [0.25, 0.5, 1.0, 2.0]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: XWSpace.x6) {
                header
                dateRangeSection
                animationSection
                networkSection
            }
            .padding(.horizontal, XWSpace.x5)
            .padding(.vertical, XWSpace.x6)
        }
        .background(XWColor.backgroundPrimary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Timeline")
                .xwTitle()
                .foregroundStyle(XWColor.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(XWFont.subheader)
                    .foregroundStyle(XWColor.textTertiary)
            }
            .accessibilityLabel("Close timeline settings")
        }
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: XWSpace.x3) {
            Text("Date range")
                .xwOverline()

            XWDivider()

            valueRow(icon: "arrow.left", title: "Start", value: Self.dateTimeFormatter.string(from: startDate))
            offsetRow { component, value in
                adjust(&startDate, by: component, value)
            }

            valueRow(icon: "arrow.right", title: "End", value: Self.dateTimeFormatter.string(from: endDate))
            offsetRow { component, value in
                adjust(&endDate, by: component, value)
            }

            Text("Shift the start and end times by adding or removing hour or day intervals.")
                .xwSmall()
                .foregroundStyle(XWColor.textSecondary)
        }
    }

    private var animationSection: some View {
        VStack(alignment: .leading, spacing: XWSpace.x3) {
            Text("Animation")
                .xwOverline()

            XWDivider()

            valueRow(icon: "clock", title: "Speed", value: Self.label(for: selectedSpeed))

            HStack(spacing: XWSpace.x2) {
                ForEach(Self.speeds, id: \.self) { speed in
                    Button(Self.label(for: speed)) {
                        selectedSpeed = speed
                    }
                    .buttonStyle(XWChipButtonStyle(isSelected: selectedSpeed == speed))
                }
            }
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: XWSpace.x3) {
            Text("Network")
                .xwOverline()

            XWDivider()

            Toggle(isOn: $isPreloadEnabled) {
                Label("Preload animated data", systemImage: "network")
                    .xwSubheader()
                    .foregroundStyle(XWColor.textPrimary)
            }
            .tint(XWColor.accent)
        }
    }

    private func valueRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: XWSpace.x2) {
            Image(systemName: icon)
                .font(XWFont.small)
                .foregroundStyle(XWColor.textTertiary)
            Text(title)
                .xwSubheader()
                .foregroundStyle(XWColor.textPrimary)
            Spacer()
            Text(value)
                .xwDataValue()
                .foregroundStyle(XWColor.textSecondary)
        }
    }

    private func offsetRow(_ adjust: @escaping (Calendar.Component, Int) -> Void) -> some View {
        HStack(spacing: XWSpace.x2) {
            Button("−1 day") { adjust(.day, -1) }
            Button("−1 hour") { adjust(.hour, -1) }
            Button("+1 hour") { adjust(.hour, 1) }
            Button("+1 day") { adjust(.day, 1) }
        }
        .buttonStyle(XWChipButtonStyle())
    }

    private func adjust(_ date: inout Date, by component: Calendar.Component, _ value: Int) {
        date = Calendar.current.date(byAdding: component, value: value, to: date) ?? date
    }

    private static func label(for speed: Double) -> String {
        speed == 1.0 ? "1x" : String(format: "%.2gx", speed)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy h:mm a"
        return f
    }()
}

#Preview {
    TimelineView(
        timelinePosition: .constant(0.3),
        startDate: .constant(Calendar.current.date(byAdding: .hour, value: -1, to: .now)!),
        endDate: .constant(Date()),
        currentDate: .constant(Date()),
        selectedSpeed: .constant(1.0),
        isPlaying: .constant(false),
        isLoading: .constant(true),
        isPreloadEnabled: .constant(false)
    )
    .padding(XWSpace.x4)
    .background(XWColor.backgroundPrimary)
}
