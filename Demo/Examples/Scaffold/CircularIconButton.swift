//
//  CircularIconButton.swift
//  Demo
//

import SwiftUI

/// A round icon button for the controls that float over a map.
///
/// Icons are SF Symbols, so they carry the reader's text size and weight settings
/// and stay sharp at any scale. Its fill is the design system's overlay card,
/// matching the panels it sits beside.
struct CircularIconButton: View {
    let systemName: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    init(
        systemName: String,
        size: CGFloat = 44,
        backgroundColor: Color = XWColor.overlaySurface,
        foregroundColor: Color = XWColor.textPrimary,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .regular))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .xwCircularSurface(size: size, fill: backgroundColor)
    }
}

#Preview {
    HStack(spacing: XWSpace.x3) {
        CircularIconButton(systemName: "chevron.backward") {}
        CircularIconButton(systemName: "square.stack.3d.up") {}
        CircularIconButton(systemName: "location") {}
    }
    .padding(XWSpace.x8)
    .background(XWColor.backgroundSecondary)
}
