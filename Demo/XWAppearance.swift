//
//  XWAppearance.swift
//  Demo
//

import MapsGLMaps
import SwiftUI
import UIKit

// The Xweather design system, as much of it as this demo uses: brand ramps, the
// semantic colors and type roles built on them, the spacing and elevation scales,
// and the few components the demo's chrome is made of.
//
// It styles the demo's own chrome only — the example browser, the sidebar, the
// floating panels. An example's body never reaches for these; an example shows SDK
// API, and styling it would bury that in tokens a reader cannot use.

// MARK: - Palette

/// The Xweather brand color ramps.
///
/// Raw values with no appearance behavior. UI reaches for the semantic colors in
/// ``XWColor`` instead, which choose from these ramps per appearance.
enum XWPalette {
    // MARK: Xweather Black — the primary dark palette

    static let black900 = UIColor(rgbHex: 0x09151C)
    static let black800 = UIColor(rgbHex: 0x0E1F2C)
    static let black700 = UIColor(rgbHex: 0x263541)
    static let black600 = UIColor(rgbHex: 0x3E4C56)
    static let black500 = UIColor(rgbHex: 0x56626B)

    // MARK: Misty Gray — neutral mid-tones

    static let gray700 = UIColor(rgbHex: 0x66828C)
    static let gray600 = UIColor(rgbHex: 0x859BA3)
    static let gray500 = UIColor(rgbHex: 0xA3B4BA)
    static let gray400 = UIColor(rgbHex: 0xC2CDD1)
    static let gray300 = UIColor(rgbHex: 0xD8E2E5)
    static let gray200 = UIColor(rgbHex: 0xEDF1F3)
    static let gray100 = UIColor(rgbHex: 0xF0F3F4)

    // MARK: Misty Green — the teal accent

    static let teal500 = UIColor(rgbHex: 0xA6D7D4)

    /// The teal accent darkened to carry text and glyph weight on light surfaces,
    /// where ``teal500`` is too pale to read.
    static let tealDeep = UIColor(rgbHex: 0x2D8A83)
}

extension UIColor {
    /// A color from a packed `0xRRGGBB` value.
    convenience init(rgbHex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgbHex >> 16) & 0xFF) / 255,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
            blue: CGFloat(rgbHex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// A color that resolves to `light` or `dark` with the trait environment.
    static func xwDynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

// MARK: - Semantic colors

/// The semantic colors of the design system.
///
/// Every member resolves against the surrounding appearance, so a view inside a
/// forced-dark container picks up the dark values without asking. ``UI`` holds the
/// UIKit form of the same set, for appearance proxies and the few places that need
/// a `UIColor`.
enum XWColor {
    enum UI {
        // MARK: Backgrounds and surfaces

        static let backgroundPrimary = UIColor.xwDynamic(light: .white, dark: XWPalette.black900)
        static let backgroundSecondary = UIColor.xwDynamic(light: XWPalette.gray100, dark: XWPalette.black800)
        static let backgroundTertiary = UIColor.xwDynamic(light: XWPalette.gray200, dark: XWPalette.black700)

        static let surface = UIColor.xwDynamic(light: .white, dark: XWPalette.black800)

        /// A wash marking a selected or hovered row against its surface.
        static let surfaceOverlay = UIColor.xwDynamic(
            light: UIColor(white: 0.04, alpha: 0.06),
            dark: UIColor(white: 1, alpha: 0.06)
        )

        /// The fill of a panel floating over a map. Follows the appearance, as the
        /// basemap under it does; its border and elevation are what separate it
        /// from the map, not a fixed contrast against one.
        static let overlaySurface = UIColor.xwDynamic(
            light: UIColor.white.withAlphaComponent(0.92),
            dark: XWPalette.black800.withAlphaComponent(0.92)
        )

        // MARK: Text

        static let textPrimary = UIColor.xwDynamic(
            light: XWPalette.black900,
            dark: UIColor(white: 1, alpha: 0.92)
        )

        /// 6.3:1 on the light surface, 11.4:1 on the dark one. The design system
        /// names Misty Gray for secondary text, which carries on a dark ground but
        /// reaches only 4.1:1 on white — under the 4.5:1 body copy needs — so the
        /// light side takes the equivalent step off the Xweather Black ramp.
        static let textSecondary = UIColor.xwDynamic(light: XWPalette.black500, dark: XWPalette.gray400)

        /// 4.1:1 on the light surface: enough for a glyph or a rule, which need
        /// 3:1, and not enough for text.
        static let textTertiary = UIColor.xwDynamic(light: XWPalette.gray700, dark: XWPalette.gray500)

        /// Overlines are 11pt and uppercase, which is where a soft gray fails
        /// first, so they carry the same weight of color as secondary text. Their
        /// hierarchy comes from size, tracking and case rather than from being faint.
        static let textOverline = UIColor.xwDynamic(light: XWPalette.black500, dark: XWPalette.gray500)
        static let textInverse = UIColor.xwDynamic(light: .white, dark: XWPalette.black900)

        // MARK: Borders and accent

        static let border = UIColor.xwDynamic(
            light: XWPalette.gray300,
            dark: UIColor(white: 1, alpha: 0.10)
        )
        static let borderSubtle = UIColor.xwDynamic(
            light: XWPalette.gray200,
            dark: UIColor(white: 1, alpha: 0.06)
        )

        /// Marks the one piece of data or the one active state that matters in a
        /// view. The design system allows a single accent per screen.
        static let accent = UIColor.xwDynamic(light: XWPalette.tealDeep, dark: XWPalette.teal500)

        /// Shadow tints, one per elevation step. Dark appearances carry more of
        /// them: elevation has to read against a dark ground.
        static func shadow(light: CGFloat, dark: CGFloat) -> UIColor {
            .xwDynamic(
                light: XWPalette.black900.withAlphaComponent(light),
                dark: UIColor(white: 0, alpha: dark)
            )
        }
    }

    static let backgroundPrimary = Color(UI.backgroundPrimary)
    static let backgroundSecondary = Color(UI.backgroundSecondary)
    static let backgroundTertiary = Color(UI.backgroundTertiary)

    static let surface = Color(UI.surface)
    static let surfaceOverlay = Color(UI.surfaceOverlay)
    static let overlaySurface = Color(UI.overlaySurface)

    static let textPrimary = Color(UI.textPrimary)
    static let textSecondary = Color(UI.textSecondary)
    static let textTertiary = Color(UI.textTertiary)
    static let textOverline = Color(UI.textOverline)
    static let textInverse = Color(UI.textInverse)

    static let border = Color(UI.border)
    static let borderSubtle = Color(UI.borderSubtle)

    static let accent = Color(UI.accent)

    static func shadow(light: CGFloat, dark: CGFloat) -> Color {
        Color(UI.shadow(light: light, dark: dark))
    }
}

// MARK: - Typography

/// The type roles, drawn in the platform's own faces.
///
/// The brand's Vaisala Sans family is not bundled — the demo ships no font files —
/// so the roles are built on the system faces. Everything else the design system
/// specifies is kept: headings are Light, labels and controls are Medium, body copy
/// is Regular, and each role carries its own tracking.
///
/// Each role is a Dynamic Type text style, so the app scales with the reader's text
/// size. Apply one with its ``SwiftUI/View`` modifier — `xwHeading()`, `xwOverline()`
/// and the rest — which sets the face and its tracking together.
enum XWFont {
    /// h2.
    static let title = Font.system(.title).weight(.light)

    /// h3. The heading of a panel or a sidebar.
    static let heading = Font.system(.title2).weight(.light)

    /// A labelled row or a field label. Medium, never bold.
    static let subheader = Font.system(.subheadline).weight(.medium)

    static let body = Font.system(.body)
    static let small = Font.system(.footnote)

    /// The uppercase label that names a section above its content.
    static let overline = Font.system(.caption2).weight(.medium)

    /// A headline number — a clock readout, a measurement. Tabular, so the digits
    /// stop shifting as the value changes.
    static let dataDisplay = Font.system(.title2).weight(.light).monospacedDigit()

    /// A numeric value at body size.
    static let dataValue = Font.system(.subheadline).monospacedDigit()

    /// Buttons, pickers and segmented controls.
    static let control = Font.system(.subheadline).weight(.medium)
}

/// Letter spacing per role, in points at the default content size.
///
/// The design system states tracking in ems — -0.03em on headlines, 0.08em on
/// overlines — which these resolve against each role's nominal size.
enum XWTracking {
    static let display: CGFloat = -1.02
    static let title: CGFloat = -0.84
    static let heading: CGFloat = -0.66
    static let subheader: CGFloat = 0.6
    static let body: CGFloat = 0
    static let overline: CGFloat = 0.88
    static let control: CGFloat = 0.15
}

extension View {
    /// h2, with headline tracking.
    func xwTitle() -> some View {
        font(XWFont.title).tracking(XWTracking.title)
    }

    /// h3, with headline tracking.
    func xwHeading() -> some View {
        font(XWFont.heading).tracking(XWTracking.heading)
    }

    func xwSubheader() -> some View {
        font(XWFont.subheader).tracking(XWTracking.subheader)
    }

    func xwBody() -> some View {
        font(XWFont.body).tracking(XWTracking.body)
    }

    func xwSmall() -> some View {
        font(XWFont.small)
    }

    /// The uppercase section label, in overline text.
    func xwOverline() -> some View {
        font(XWFont.overline)
            .tracking(XWTracking.overline)
            .textCase(.uppercase)
            .foregroundStyle(XWColor.textOverline)
    }

    /// A headline number, tabular and tracked like a heading.
    func xwDataDisplay() -> some View {
        font(XWFont.dataDisplay).tracking(XWTracking.heading)
    }

    func xwDataValue() -> some View {
        font(XWFont.dataValue)
    }
}

extension UIFont {
    /// h1 in UIKit, for the appearance proxies that style the navigation bar.
    static func xwDisplay(size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .light)
    }

    /// A labelled control in UIKit.
    static func xwSubheader(size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }
}

// MARK: - Metrics

/// The 4pt spacing grid. Every inset, gap and padding in the demo's chrome comes
/// from here, so the app keeps one rhythm.
enum XWSpace {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x7: CGFloat = 28
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
    static let x12: CGFloat = 48
}

/// Corner radii. Cards and inputs stop at ``md``; anything rounder reads as
/// decoration rather than structure.
enum XWRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
}

enum XWBorder {
    static let width: CGFloat = 1

    /// The width of a border drawn inside a shape, where a full point reads heavy.
    static let hairline: CGFloat = 0.5
}

/// Elevation, for what floats — map overlays, popovers. Flat content separates
/// with borders instead.
enum XWShadow {
    struct Spec {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    static let sm = Spec(color: XWColor.shadow(light: 0.08, dark: 0.30), radius: 3, y: 1)
    static let md = Spec(color: XWColor.shadow(light: 0.10, dark: 0.40), radius: 12, y: 4)
    static let lg = Spec(color: XWColor.shadow(light: 0.12, dark: 0.50), radius: 32, y: 8)
}

/// Animation timings.
///
/// Qualified: `MapsGLMaps` declares an `Animation` of its own.
enum XWMotion {
    static let fast: SwiftUI.Animation = .easeInOut(duration: 0.12)
    static let base: SwiftUI.Animation = .easeInOut(duration: 0.2)
    static let layout: SwiftUI.Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.4)
}

extension View {
    func xwShadow(_ spec: XWShadow.Spec) -> some View {
        shadow(color: spec.color, radius: spec.radius, y: spec.y)
    }
}

// MARK: - Components

extension View {
    /// The data panel the design system specifies for map overlays: a surface fill,
    /// a hairline border, one step of elevation, and a `md` corner.
    ///
    /// Follows the system appearance, so it matches both the basemap under it and
    /// the rest of the app. Anything placed inside — a picker, a slider, a caption —
    /// reads correctly without styling itself.
    func xwOverlayCard(
        horizontalPadding: CGFloat = XWSpace.x4,
        verticalPadding: CGFloat = XWSpace.x3,
        cornerRadius: CGFloat = XWRadius.md
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(XWColor.overlaySurface, in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(XWColor.border, lineWidth: XWBorder.hairline))
            .xwShadow(XWShadow.md)
    }
}

extension View {
    /// The round surface the floating map controls share: the overlay fill, a
    /// material behind it, and a hairline border.
    func xwCircularSurface(size: CGFloat, fill: Color = XWColor.overlaySurface) -> some View {
        frame(width: size, height: size)
            .background(fill, in: Circle())
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(XWColor.border, lineWidth: XWBorder.hairline))
    }
}

/// The rule that separates horizontal zones. A border, not a shadow.
struct XWDivider: View {
    var color: Color = XWColor.borderSubtle

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: XWBorder.hairline)
    }
}

/// A compact selectable control: an animation speed, a time offset, a filter.
///
/// Selected is the accent state, and the design system allows one accent per view —
/// so a screen uses this for the one choice that matters, not for every button on it.
struct XWChipButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XWFont.control)
            .tracking(XWTracking.control)
            .padding(.vertical, XWSpace.x2)
            .padding(.horizontal, XWSpace.x3)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? XWColor.textInverse : XWColor.textPrimary)
            .background(isSelected ? XWColor.accent : XWColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: XWRadius.sm, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(XWMotion.fast, value: configuration.isPressed)
    }
}

// MARK: - Legend

/// Brings the SDK's legend onto these tokens, using only ``LegendControl``'s public
/// interface.
///
/// ``LegendControlView`` renders whichever ``LegendControl`` its host has installed,
/// creating a default one if the host has none. The demo therefore installs a styled
/// control on the map controller before any legend view is built, and every legend
/// in the app picks it up.
///
/// This doubles as the worked example of customizing a legend. The two things worth
/// knowing are here: install your own control before the view can create one, and
/// everything the container and its titles look like is set on ``LegendControl``
/// itself, which carries it to whichever legends the layers bring with them.
enum XWLegendStyle {
    /// Legend titles are labels, so they take the design system's Medium weight
    /// rather than the control's default Bold.
    static let titleFont = UIFont.systemFont(ofSize: 12, weight: .medium)

    /// A control styled to match the demo's overlay cards.
    @MainActor
    static func makeControl(colorScheme: ColorScheme) -> LegendControl {
        let control = LegendControl()
        apply(to: control, colorScheme: colorScheme)
        return control
    }

    /// Applies the tokens to `control`.
    ///
    /// Call it again when the appearance changes: the fill and the legends' own
    /// colors follow it on their own, but the border and shadow are `CGColor`s on a
    /// layer, which hold whatever they resolved to when they were set.
    @MainActor
    static func apply(to control: LegendControl, colorScheme: ColorScheme) {
        // An opaque fill. The legend fades its scrolling content out against this
        // color, so a translucent one would show the fade as a band over the map.
        control.backgroundColor = XWColor.UI.surface
        control.cornerRadius = XWRadius.md
        control.insets = UIEdgeInsets(
            top: XWSpace.x3,
            left: XWSpace.x3,
            bottom: XWSpace.x3,
            right: XWSpace.x3
        )

        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let layer = control.view.layer
        layer.borderWidth = XWBorder.hairline
        layer.borderColor = XWColor.UI.border.resolvedColor(with: traits).cgColor

        // The same elevation the control panels carry, so the legend reads as one of
        // them rather than as part of the map.
        let shadow = XWColor.UI.shadow(light: 0.10, dark: 0.40)
        layer.shadowColor = shadow.resolvedColor(with: traits).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // Carried by the control, so the legends layers add later are styled as they
        // arrive rather than needing a pass of their own.
        control.titleFont = titleFont
        control.titleColor = XWColor.UI.textOverline
    }
}

// MARK: - Appearance proxies

/// Applies the type roles to the navigation bar, which SwiftUI draws through UIKit
/// and which takes its styling from an appearance proxy rather than from modifiers.
///
/// Call ``apply()`` once, at launch, before any window is shown.
enum XWAppearance {
    static func apply() {
        // Type only. The bar's background, its border and its scroll-edge behavior
        // stay with the system: configuring a background here leaves the navigation
        // bar reserving space for its title and drawing nothing in it.
        let navigationBar = UINavigationBarAppearance()

        navigationBar.largeTitleTextAttributes = [
            .font: UIFont.xwDisplay(size: 34),
            .foregroundColor: XWColor.UI.textPrimary,
            .kern: XWTracking.display
        ]
        navigationBar.titleTextAttributes = [
            .font: UIFont.xwSubheader(size: 17),
            .foregroundColor: XWColor.UI.textPrimary
        ]

        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
    }
}
