//
//  TimelineControlsExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Driving the map's timeline: play, pause, resume, and scrub.
///
/// `MapController.timeline` animates every layer on the map together. `play()` and
/// `stop()` start and end a run; `pause()` and `resume()` hold the playhead where it
/// is without ending it; `goTo(position:)` scrubs to a normalized `0...1` position.
/// Observing `onAdvance` keeps your own UI in step with the playhead — including
/// while it advances on its own, which is what makes the slider track playback rather
/// than fight it.
struct TimelineControlsExample: View {
    @State private var position: Double = 0
    @State private var currentDate = Date()
    @State private var isActive = false
    @State private var isPaused = false

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -85.5), zoom: 3) { mapController, subscriptions in
            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .temperatures
                )
                try mapController.addWeatherLayer(for: .temperatures, beforeId: beforeId)
            } catch {
                print("Failed to add the temperatures layer: \(error)")
            }

            let timeline = mapController.timeline
            currentDate = timeline.currentDate

            timeline.onAdvance.publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak timeline] _ in
                    guard let timeline else { return }
                    position = timeline.position
                    currentDate = timeline.currentDate
                }
                .store(in: &subscriptions)
        } overlay: { mapController in
            ExampleControlPanel {
                scrubber(for: mapController)
                ExampleControlGroup {
                    playback(for: mapController)
                }
            }
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
    TimelineControlsExample()
}
