//
//  PreloadAnimationDataExample.swift
//  Demo
//

import Combine
import CoreLocation
import MapsGLMaps
import SwiftUI

/// Fetching every animation frame up front so playback doesn't stall.
///
/// By default a layer loads each interval as the playhead reaches it, so the first
/// pass through the timeline is gated by the network. Setting
/// `animationOptions.shouldPreloadData` makes layers fetch their whole interval set
/// while paused; `preloadAnimationData()` starts that work immediately rather than
/// waiting for the next timeline change.
///
/// `shouldPauseWhileLoading` and `shouldResumeAfterLoading` cover the other half of
/// the problem — panning or zooming needs data for the new view, and these decide
/// whether the timeline waits for it and picks itself back up.
///
/// The tradeoff is bandwidth and memory against a smooth first loop, so it suits a
/// short timeline or a deliberate "buffering" step in your own UI.
struct PreloadAnimationDataExample: View {
    @State private var isPreloading = true
    @State private var pausesWhileLoading = true
    @State private var isBusy = false
    @State private var isActive = false
    @State private var isPaused = false

    var body: some View {
        ExampleMapView(center: CLLocationCoordinate2D(latitude: 40, longitude: -85.5), zoom: 3) { mapController, subscriptions in
            mapController.animationOptions.shouldPreloadData = isPreloading
            mapController.animationOptions.shouldPauseWhileLoading = pausesWhileLoading

            do {
                let beforeId = DemoMapProvider.weatherLayerInsertBeforeId(
                    for: mapController,
                    layerCode: .windSpeeds
                )
                try mapController.addWeatherLayer(for: .windSpeeds, beforeId: beforeId)
            } catch {
                print("Failed to add the wind speeds layer: \(error)")
            }

            // Start the fetch now rather than waiting for the first timeline change.
            Task { await mapController.preloadAnimationData() }
        } overlay: { mapController in
            ExampleControlPanel {
                ExampleControlGroup(title: "Loading") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Preload animation data", isOn: $isPreloading)
                            .font(.subheadline)
                            .onChange(of: isPreloading) { newValue in
                                mapController?.animationOptions.shouldPreloadData = newValue
                            }

                        Toggle("Pause while loading", isOn: $pausesWhileLoading)
                            .font(.subheadline)
                            .onChange(of: pausesWhileLoading) { newValue in
                                mapController?.animationOptions.shouldPauseWhileLoading = newValue
                            }
                    }
                }

                ExampleControlGroup {
                    playback(for: mapController)
                }
            }
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

            Button("Preload now") {
                guard let mapController else { return }
                isBusy = true
                Task {
                    await mapController.preloadAnimationData()
                    isBusy = false
                }
            }
            .disabled(isBusy)
        }
        .exampleControlSizing()
    }

    private func syncPlaybackState(from timeline: Timeline) {
        isActive = timeline.isActive
        isPaused = timeline.isPaused
    }
}

#Preview {
    PreloadAnimationDataExample()
}
