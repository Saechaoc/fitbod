//
//  ChalkTokens.swift
//  fitbod
//
//  Chalkline — the app's design foundation. Every visual decision that
//  repeats across screens lives here as a named token so views never
//  hard-code a hex value, a font, or a magic spacing number.
//
//  Source of truth: docs/design-system/README.md (token tables + usage
//  rules) and the "Fitbod · Chalkline design system" Claude Design canvas
//  (Foundations board). Values here must match those tables.
//
//  Identity in one line: a training logbook. Warm chalk paper for reading,
//  iron-black panels for live state ("now"), one signal orange for the
//  next thing to do, ruled tables for numbers.
//
//  ## Color
//  Semantic, not literal: `chalkInk2` means "secondary text", never "a
//  grey". Each token resolves dynamically for light / dark mode and for
//  Increase Contrast. Every text pair is ≥ 4.5:1 (see docs for ratios).
//  Use the `ShapeStyle` shorthands — `.foregroundStyle(.chalkInk2)`,
//  `.background(.chalkCanvas)` — or `Color.chalkInk2` where an API wants
//  a `Color`.
//
//  ## Type
//  SF Pro text styles only, so everything scales with Dynamic Type.
//  Condensed width + heavy weight carries the identity on headings,
//  labels, buttons and numbers; reading text stays standard width.
//
//  ## Space / shape / size
//  4-pt grid, four radii, three stroke weights, and touch-target minimums
//  (44 pt everywhere, 48 for set completion, 56 for thumb-zone primaries).
//

import SwiftUI
import UIKit

// MARK: - Namespace

/// Chalkline design tokens that are not colors or fonts.
public enum Chalk {

    /// 4-pt spacing scale.
    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
        /// Horizontal screen gutter.
        public static let gutter: CGFloat = 16
    }

    /// Corner radii. Continuous corners everywhere.
    public enum Radius {
        /// Chips, tags, set-number badges.
        public static let sm: CGFloat = 6
        /// Inputs, buttons, inline messages.
        public static let md: CGFloat = 10
        /// Cards and panels.
        public static let lg: CGFloat = 16
        /// Hero panels and the rest-timer dock.
        public static let xl: CGFloat = 24
    }

    /// Stroke weights.
    public enum Line {
        /// Row separators and card outlines.
        public static let hairline: CGFloat = 1
        /// Control outlines and the rule under table column labels.
        public static let strong: CGFloat = 1.5
        /// Focus ring (accent).
        public static let focus: CGFloat = 2
        /// The rule under screen titles.
        public static let heavy: CGFloat = 3
    }

    /// Touch-target and control sizes.
    public enum Size {
        /// HIG minimum for any tappable element.
        public static let minTouch: CGFloat = 44
        /// Numeric inputs inside set rows.
        public static let input: CGFloat = 44
        /// The set-complete check button.
        public static let setCheck: CGFloat = 48
        /// Regular buttons.
        public static let button: CGFloat = 50
        /// Thumb-zone primary actions (Start workout, Done).
        public static let primaryBar: CGFloat = 56
        /// Filter chips draw at 40 but keep a 44 hit area.
        public static let chip: CGFloat = 40
    }

    /// Motion durations. Callers must still respect Reduce Motion.
    public enum Motion {
        public static let quick: Double = 0.15
        public static let standard: Double = 0.25
    }

    /// Letter spacing for condensed caps (labels, buttons, chips).
    public enum Tracking {
        public static let label: CGFloat = 0.8
        public static let button: CGFloat = 0.6
        public static let title: CGFloat = 0.3
    }
}

// MARK: - Color palette

/// Raw palette resolution. Views use the semantic `ShapeStyle` members
/// below; this type exists so UIKit appearance code and tests can reach
/// the same values.
public enum ChalkPalette {

    /// One semantic token: light, dark, and optional Increase Contrast
    /// overrides, stored as 0xRRGGBB.
    public struct Token: Sendable, Equatable {
        public let light: UInt32
        public let dark: UInt32
        public let lightHighContrast: UInt32?
        public let darkHighContrast: UInt32?

        public init(light: UInt32, dark: UInt32, lightHighContrast: UInt32? = nil, darkHighContrast: UInt32? = nil) {
            self.light = light
            self.dark = dark
            self.lightHighContrast = lightHighContrast
            self.darkHighContrast = darkHighContrast
        }

        /// Resolves the hex for a given appearance.
        public func hex(dark isDark: Bool, highContrast: Bool) -> UInt32 {
            if isDark {
                return (highContrast ? darkHighContrast : nil) ?? dark
            }
            return (highContrast ? lightHighContrast : nil) ?? light
        }

        /// A trait-aware `UIColor`.
        public var uiColor: UIColor {
            let token = self
            return UIColor { traits in
                let hex = token.hex(
                    dark: traits.userInterfaceStyle == .dark,
                    highContrast: traits.accessibilityContrast == .high
                )
                return UIColor(chalkHex: hex)
            }
        }

        /// A trait-aware SwiftUI `Color`.
        public var color: Color { Color(uiColor: uiColor) }
    }

    // Surfaces
    public static let canvas = Token(light: 0xF2EEE5, dark: 0x11100E)
    public static let surface = Token(light: 0xFBF9F4, dark: 0x1C1A17)
    public static let sunken = Token(light: 0xE6E1D4, dark: 0x282621, lightHighContrast: 0xDDD6C6)
    public static let complete = Token(light: 0xE3DDCF, dark: 0x24221E)

    // Ink (text + icons)
    public static let ink = Token(light: 0x171614, dark: 0xF2EEE5)
    public static let ink2 = Token(light: 0x57534B, dark: 0xB5AFA1, lightHighContrast: 0x3F3C36, darkHighContrast: 0xD2CCBE)
    public static let ink3 = Token(light: 0x66615A, dark: 0x9A9487, lightHighContrast: 0x4A4640, darkHighContrast: 0xC2BCAE)
    public static let divider = Token(light: 0xCFC7B6, dark: 0x38352F, lightHighContrast: 0x9E9583, darkHighContrast: 0x5A564E)

    // Iron panels
    public static let panel = Token(light: 0x171614, dark: 0x2A2723)
    public static let panelRaised = Token(light: 0x2B2925, dark: 0x36332E)
    public static let panelBorder = Token(light: 0x171614, dark: 0x403C36)
    public static let onPanel = Token(light: 0xF2EEE5, dark: 0xF2EEE5)
    public static let onPanel2 = Token(light: 0xB4AE9F, dark: 0xB8B2A4, lightHighContrast: 0xD6D0C2, darkHighContrast: 0xD6D0C2)

    // Signal
    public static let accent = Token(light: 0xEC4E25, dark: 0xFF6A3D)
    public static let onAccent = Token(light: 0x171614, dark: 0x171614)
    public static let accentInk = Token(light: 0xAD3510, dark: 0xFF7F57, lightHighContrast: 0x8F2A0B)
    public static let accentOnPanel = Token(light: 0xFF6E42, dark: 0xFF8A63)
    public static let danger = Token(light: 0xB42318, dark: 0xFF7B6E, lightHighContrast: 0x8F1A12)
}

extension UIColor {
    /// 0xRRGGBB → opaque sRGB color.
    public convenience init(chalkHex hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Semantic color shorthands

extension ShapeStyle where Self == Color {
    /// App background — warm chalk paper.
    public static var chalkCanvas: Color { ChalkPalette.canvas.color }
    /// Cards, rows, sheets.
    public static var chalkSurface: Color { ChalkPalette.surface.color }
    /// Input wells, idle chips, segmented tracks.
    public static var chalkSunken: Color { ChalkPalette.sunken.color }
    /// Completed-set row tint.
    public static var chalkComplete: Color { ChalkPalette.complete.color }
    /// Primary text, icons, outlines, rules.
    public static var chalkInk: Color { ChalkPalette.ink.color }
    /// Secondary text.
    public static var chalkInk2: Color { ChalkPalette.ink2.color }
    /// Captions and placeholders (still ≥ 4.5:1).
    public static var chalkInk3: Color { ChalkPalette.ink3.color }
    /// Hairline separators.
    public static var chalkDivider: Color { ChalkPalette.divider.color }
    /// Iron panel fill — live state.
    public static var chalkPanel: Color { ChalkPalette.panel.color }
    /// Controls placed on a panel.
    public static var chalkPanelRaised: Color { ChalkPalette.panelRaised.color }
    /// Panel outline (visible in dark mode, invisible in light).
    public static var chalkPanelBorder: Color { ChalkPalette.panelBorder.color }
    /// Text on panels.
    public static var chalkOnPanel: Color { ChalkPalette.onPanel.color }
    /// Secondary text on panels.
    public static var chalkOnPanel2: Color { ChalkPalette.onPanel2.color }
    /// Primary-action fill, progress, focus ring. Never body text.
    public static var chalkAccent: Color { ChalkPalette.accent.color }
    /// Text/icons placed on an accent fill.
    public static var chalkOnAccent: Color { ChalkPalette.onAccent.color }
    /// Accent-colored text on paper.
    public static var chalkAccentInk: Color { ChalkPalette.accentInk.color }
    /// Accent-colored text on panels.
    public static var chalkAccentOnPanel: Color { ChalkPalette.accentOnPanel.color }
    /// Errors and destructive actions.
    public static var chalkDanger: Color { ChalkPalette.danger.color }
}

// MARK: - Typography

extension Font {
    /// Screen hero titles ("PUSH DAY A"). largeTitle · heavy · condensed.
    public static var chalkDisplay: Font {
        .system(.largeTitle, design: .default, weight: .heavy).width(.condensed)
    }

    /// Section and sheet titles. title2 · bold · condensed.
    public static var chalkTitle: Font {
        .system(.title2, design: .default, weight: .bold).width(.condensed)
    }

    /// Small section headings inside cards. title3 · heavy · condensed.
    public static var chalkSubtitle: Font {
        .system(.title3, design: .default, weight: .heavy).width(.condensed)
    }

    /// Exercise and routine names. headline · semibold · standard width
    /// (names wrap; never uppercased).
    public static var chalkHeadline: Font {
        .system(.headline, design: .default, weight: .semibold)
    }

    /// Reading text.
    public static var chalkBody: Font { .body }

    /// Supporting copy.
    public static var chalkCallout: Font { .callout }

    /// Meta lines ("Barbell · Chest · Triceps").
    public static var chalkFootnote: Font { .footnote }

    /// Overlines, column labels, chip text. caption · bold · condensed.
    /// Pair with `.textCase(.uppercase)` + `.tracking(Chalk.Tracking.label)`.
    public static var chalkLabel: Font {
        .system(.caption, design: .default, weight: .bold).width(.condensed)
    }

    /// Chip text. subheadline · bold · condensed.
    public static var chalkChip: Font {
        .system(.subheadline, design: .default, weight: .bold).width(.condensed)
    }

    /// Button labels. headline · heavy · condensed.
    public static var chalkButton: Font {
        .system(.headline, design: .default, weight: .heavy).width(.condensed)
    }

    /// Set inputs, best sets, inline numbers. title3 · heavy · condensed ·
    /// monospaced digits.
    public static var chalkMetric: Font {
        .system(.title3, design: .default, weight: .heavy).width(.condensed).monospacedDigit()
    }

    /// Metric tiles. title · heavy · condensed · monospaced digits.
    public static var chalkMetricLarge: Font {
        .system(.title, design: .default, weight: .heavy).width(.condensed).monospacedDigit()
    }
}

// MARK: - Text treatments

extension View {
    /// Condensed caps label treatment (overlines, column headers).
    public func chalkLabelStyle(color: Color = .chalkInk2) -> some View {
        self
            .font(.chalkLabel)
            .textCase(.uppercase)
            .tracking(Chalk.Tracking.label)
            .foregroundStyle(color)
    }

    /// Paper canvas behind a scrolling container (List / ScrollView).
    public func chalkCanvasBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background {
                Color.chalkCanvas.ignoresSafeArea()
            }
    }
}
