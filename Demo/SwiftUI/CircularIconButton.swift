//
//  CircleIconButton.swift
//  Demo
//
//  Created by Nicholas Shipes on 4/30/25.
//

import SwiftUI

struct CircularIconButton: View {
    enum Icon {
        case system(name: String)
        case custom(name: String)
    }

    let icon: Icon
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let insets: EdgeInsets
    let action: () -> Void

    // SF Symbol initializer
    init(
        systemName: String,
        size: CGFloat = 44,
        backgroundColor: Color = Color.backgroundColor,
        foregroundColor: Color = .textColor,
        insets: EdgeInsets = EdgeInsets(),
        action: @escaping () -> Void
    ) {
        self.icon = .system(name: systemName)
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.insets = insets
        self.action = action
    }

    // Custom asset initializer
    init(
        imageName: String,
        size: CGFloat = 44,
        backgroundColor: Color = Color.backgroundColor,
        foregroundColor: Color = .textColor,
        insets: EdgeInsets = EdgeInsets(),
        action: @escaping () -> Void
    ) {
        self.icon = .custom(name: imageName)
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.insets = insets
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            image
                .renderingMode(.template)
                .resizable().scaledToFit()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.5, height: size * 0.5)
                .frame(width: size, height: size)
                .padding(insets)
                .foregroundColor(foregroundColor)
        }
        .background(backgroundColor)
        .clipShape(Circle())
    }
    
    private var image: Image {
        switch icon {
        case .system(let name):
            return Image(systemName: name)
        case .custom(let name):
            return Image(name)
        }
    }
}
