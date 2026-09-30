//
//  ExampleContainer.swift
//  Demo
//

import SwiftUI

/// Layout constants shared between ``ExampleContainer`` and the controls an example
/// draws over its own map. All of them come off the design system's 4pt grid.
enum ExampleChrome {
    /// Diameter of the floating back button.
    static let backButtonSize: CGFloat = 44

    /// Gap between the safe area and the first floating control.
    static let topPadding: CGFloat = XWSpace.x2

    /// Horizontal inset for floating controls.
    static let horizontalPadding: CGFloat = XWSpace.x3

    /// Diameter of the loading indicator. Smaller than the back button it sits
    /// opposite: it reports, it is not something to press.
    static let loadingIndicatorSize: CGFloat = 32

    /// Top inset for an example's own top-leading controls, clearing the back button.
    /// Collapses to ``topPadding`` when the back button is not drawn, so a capture
    /// does not reserve a gap for it.
    static var controlsTopInset: CGFloat {
        ExampleCaptureMode.hidesControls ? topPadding : topPadding + backButtonSize + topPadding
    }

    /// Space kept clear at the bottom of an example for the map's own logo and
    /// attribution, which stay pinned to the map's edge.
    ///
    /// Attribution has to be legible — both mapping libraries require it — and
    /// leaving it where a reader expects it beats floating it partway up the map.
    /// A constant rather than a measurement: neither library publishes its ornament
    /// sizes, and they don't change.
    static let bottomOrnamentClearance: CGFloat = 36
}

/// Wraps a pushed example so the map gets the whole screen.
///
/// The navigation bar is hidden — a title bar over a full-bleed map is chrome without
/// content — and replaced by a floating back button in the same style as the demo's
/// other map controls. An example's own top-leading controls should start at
/// ``ExampleChrome/controlsTopInset`` so they clear it.
struct ExampleContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                if ExampleCaptureMode.hidesControls {
                    EmptyView()
                } else {
                    CircularIconButton(
                        systemName: "chevron.backward",
                        size: ExampleChrome.backButtonSize
                    ) {
                        dismiss()
                    }
                    .xwShadow(XWShadow.md)
                    .padding(.top, ExampleChrome.topPadding)
                    .padding(.horizontal, ExampleChrome.horizontalPadding)
                    .accessibilityLabel("Back to examples")
                }
            }
    }
}
