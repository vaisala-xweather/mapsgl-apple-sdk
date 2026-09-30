//
//  ExampleControlPanel.swift
//  Demo
//

import SwiftUI

/// The floating surface every example's controls sit on.
///
/// One place decides material, shape, border, shadow and inset, so a screenful of
/// examples reads as one app rather than a pile of one-off overlays. Anchored to the
/// bottom: the top belongs to ``ExampleContainer``'s back button, and the bottom is
/// where a thumb reaches.
///
/// Compose it with ``ExampleControlGroup`` for a labelled cluster of controls.
struct ExampleControlPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: XWSpace.x3) {
                content()
            }
            .exampleControlSurface()
        }
    }
}

/// A labelled cluster inside a panel. The label is optional — a single control
/// usually explains itself, and a caption above it would be noise.
struct ExampleControlGroup<Content: View>: View {
    var title: String?

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: XWSpace.x2) {
            if let title {
                Text(title)
                    .xwOverline()
            }
            content()
        }
    }
}

extension View {
    /// The panel's visual treatment on its own, for a control that needs its own
    /// surface rather than a slot in the shared panel.
    func exampleControlSurface() -> some View {
        Group {
            // Screenshots for the documentation show what an example draws, not the
            // controls for driving it. See ``ExampleCaptureMode``.
            if ExampleCaptureMode.hidesControls {
                EmptyView()
            } else {
                self
                    .xwOverlayCard(
                        horizontalPadding: XWSpace.x4,
                        verticalPadding: XWSpace.x3
                    )
                    .padding(.horizontal, XWSpace.x4)
                    .padding(.bottom, XWSpace.x4)
            }
        }
    }

    /// Sizing shared by every example that floats the SDK's legend above its controls.
    func exampleLegendFrame(maxHeight: CGFloat = 220) -> some View {
        self
            .frame(maxWidth: 360, maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, XWSpace.x4)
    }

    /// Sizing shared by the small buttons and pickers inside a panel.
    func exampleControlSizing() -> some View {
        self
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(XWFont.control)
            .tracking(XWTracking.control)
    }
}
