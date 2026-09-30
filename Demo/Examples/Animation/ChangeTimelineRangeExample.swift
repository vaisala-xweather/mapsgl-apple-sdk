//
//  ChangeTimelineRangeExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Moving the timeline's start and end independently, while it runs.
///
/// `timeline.startDate` and `timeline.endDate` bound the window every layer animates
/// over. Assigning either one re-scales the playhead and makes each layer re-resolve
/// the intervals it needs, so widening from a day of history to a week is one
/// assignment rather than a teardown.
struct ChangeTimelineRangeExample: View {
    /// Offsets from now, in hours — the same set the JavaScript example offers.
    private enum Offset: Int, CaseIterable, Identifiable {
        case now = 0
        case oneDay = 24
        case threeDays = 72
        case sevenDays = 168

        var id: Int { rawValue }

        func label(isStart: Bool) -> String {
            switch self {
            case .now: "Now"
            case .oneDay: isStart ? "-1 day" : "+1 day"
            case .threeDays: isStart ? "-3 days" : "+3 days"
            case .sevenDays: isStart ? "-7 days" : "+7 days"
            }
        }
    }

    @State private var startOffset: Offset = .now
    @State private var endOffset: Offset = .oneDay
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var position: Double = 0
    @State private var currentDate = Date()
    @State private var isActive = false
    @State private var isPaused = false

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 47, longitude: 20), zoom: 4) { mapController, subscriptions in
            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .windParticles
                )
                try mapController.addWeatherLayer(for: .windParticles, beforeId: beforeId)
            } catch {
                print("Failed to add the wind particles layer: \(error)")
            }

            applyRange(to: mapController)

            let timeline = mapController.timeline
            timeline.onAdvance.publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak timeline] _ in
                    guard let timeline else { return }
                    syncPlayhead(from: timeline)
                }
                .store(in: &subscriptions)
        } overlay: { mapController in
            ExampleControlPanel {
                ExampleControlGroup(title: "Range") {
                    HStack(alignment: .top, spacing: 24) {
                        offsetPicker("Start", selection: $startOffset, isStart: true, resolved: startDate, mapController: mapController)
                        offsetPicker("End", selection: $endOffset, isStart: false, resolved: endDate, mapController: mapController)
                    }
                }

                scrubber(for: mapController)
                ExampleControlGroup {
                    playback(for: mapController)
                }
            }
        }
    }

    @ViewBuilder
    private func offsetPicker(
        _ title: String,
        selection: Binding<Offset>,
        isStart: Bool,
        resolved: Date,
        mapController: DemoMapController?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Picker(title, selection: selection) {
                ForEach(Offset.allCases) { offset in
                    Text(offset.label(isStart: isStart)).tag(offset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection.wrappedValue) { _ in
                guard let mapController else { return }
                applyRange(to: mapController)
            }

            Text(Self.formatter.string(from: resolved))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func scrubber(for mapController: DemoMapController?) -> some View {
        HStack(spacing: 14) {
            Slider(value: $position, in: 0...1) { isEditing in
                guard let timeline = mapController?.timeline else { return }
                if isEditing {
                    // Hold the playhead while dragging so it doesn't fight the thumb.
                    timeline.pause()
                    syncPlaybackState(from: timeline)
                } else {
                    timeline.goTo(position: position)
                }
            }

            Text(Self.formatter.string(from: currentDate))
                .font(.footnote.monospacedDigit())
                .frame(width: 70, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func playback(for mapController: DemoMapController?) -> some View {
        HStack(spacing: 16) {
            Button(isActive ? "Stop" : "Play") {
                guard let timeline = mapController?.timeline else { return }
                if timeline.isActive {
                    timeline.stop()
                } else {
                    timeline.play()
                }
                syncPlaybackState(from: timeline)
            }

            Button(isPaused ? "Resume" : "Pause") {
                guard let timeline = mapController?.timeline else { return }
                if timeline.isPaused {
                    timeline.resume()
                } else {
                    timeline.pause()
                }
                syncPlaybackState(from: timeline)
            }
            .disabled(!isActive)
        }
        .exampleControlSizing()
    }

    /// Start runs back from now, end runs forward.
    private func applyRange(to mapController: DemoMapController) {
        let now = Date()
        startDate = Self.startOfHour(containing: now.addingTimeInterval(-Double(startOffset.rawValue) * 3600))
        endDate = now.addingTimeInterval(Double(endOffset.rawValue) * 3600)

        mapController.timeline.startDate = startDate
        mapController.timeline.endDate = endDate
        syncPlayhead(from: mapController.timeline)
    }

    /// The top of the hour `date` falls in.
    ///
    /// Weather data is published on the hour, and a layer draws the frame at or before
    /// the playhead. A range beginning at an arbitrary moment therefore starts *before*
    /// its own first published interval — "Now" at 15:30 asks for a window whose first
    /// frame is 16:00 — and the map stays blank until playback reaches it. Snapping the
    /// start back to the hour puts a frame under the playhead from the first draw.
    private static func startOfHour(containing date: Date) -> Date {
        Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
    }

    private func syncPlayhead(from timeline: Timeline) {
        position = timeline.position
        currentDate = timeline.currentDate
    }

    private func syncPlaybackState(from timeline: Timeline) {
        isActive = timeline.isActive
        isPaused = timeline.isPaused
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter
    }()
}

#Preview {
    ChangeTimelineRangeExample()
}
