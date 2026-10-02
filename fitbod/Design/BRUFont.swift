// BRUFont.swift
// fitbod
//
// BRU typography system. Every role is a `Font.custom(_:size:relativeTo:)`
// value, so all text scales with Dynamic Type from the base sizes below.
// Full token table and usage rules: docs/design-system/README.md § Typography.
//
// FACES (registered via UIAppFonts in Info.plist):
//   Bebas Neue Regular      — condensed display: screen titles, hero numbers
//   Space Grotesk Bold      — headings, exercise names, card titles
//   JetBrains Mono Bold     — labels, chips, data values
//   JetBrains Mono Regular  — body copy, metadata
//
// USAGE NOTES:
//   - Apply .textCase(.uppercase) at the call site for label roles (the
//     underlying string stays mixed-case for VoiceOver).
//   - Apply .tracking(n) at the call site (see the table in the docs).
//   - Bebas Neue has no lowercase; condensed roles always read as caps.
//   - Large display numbers grow fast at accessibility sizes. Pair them with
//     `.lineLimit(1).minimumScaleFactor(0.5)` where width is constrained.
//   - Never call `Font.custom` directly in feature code. Use a role, or
//     `Font.bru(_:size:)` when a one-off size is unavoidable.

import SwiftUI

// MARK: - Faces

/// The four BRU type faces, keyed by PostScript name.
public enum BRUFace: String, Sendable {
    case condensed = "BebasNeue-Regular"
    case grotesk = "SpaceGrotesk-Bold"
    case groteskSemibold = "SpaceGrotesk-SemiBold"
    case mono = "JetBrainsMono-Regular"
    case monoBold = "JetBrainsMono-Bold"
    /// Geist Regular: long-form paragraph copy only (empty-state explainers).
    case text = "Geist-Regular"
}

public extension Font {
    /// A BRU face at `size` that scales with Dynamic Type.
    ///
    /// The text style it scales relative to is inferred from the size, so a
    /// 12pt label grows like `.caption` and a 32pt heading grows like `.title`.
    static func bru(_ face: BRUFace, size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        .custom(face.rawValue, size: size, relativeTo: style ?? BRUFont.textStyle(forPointSize: size))
    }
}

// MARK: - BRUFont Namespace

public enum BRUFont {

    // MARK: Condensed display (Bebas Neue)

    /// 64pt condensed: hero metric (the weight on the active set).
    public static let condensedHero: Font = .bru(.condensed, size: 64)

    /// 40pt condensed: screen title, exercise title on the active workout.
    public static let condensedTitle: Font = .bru(.condensed, size: 40)

    /// 28pt condensed: section heroes, empty-state headlines, big readouts.
    public static let condensedHeading: Font = .bru(.condensed, size: 28)

    /// 22pt condensed: primary CTA labels ("LOG SET ▸"), metric values in strips.
    public static let condensedLabel: Font = .bru(.condensed, size: 22)

    // MARK: Display (Space Grotesk Bold)

    /// Display heavy 56pt: hero headlines.
    /// Tracking: -0.5 at call site. Case: as-typed.
    public static let displayHero: Font = .bru(.grotesk, size: 56)

    /// Display heavy 32pt: section headers.
    /// Tracking: -0.3 at call site. Case: as-typed.
    public static let displayLarge: Font = .bru(.grotesk, size: 32)

    /// Display heavy 18pt: card titles, exercise names.
    /// Tracking: 0 at call site. Case: as-typed.
    public static let displayMedium: Font = .bru(.grotesk, size: 18)

    // MARK: Body (JetBrains Mono)

    /// Mono bold 14pt: emphasized body copy, primary data values.
    /// Tracking: -0.2 at call site. Case: as-typed.
    public static let bodyEmphasis: Font = .bru(.monoBold, size: 14)

    /// Mono regular 13pt: secondary data, descriptions.
    /// Tracking: 0 at call site. Case: as-typed.
    public static let bodyDefault: Font = .bru(.mono, size: 13)

    // MARK: Labels (JetBrains Mono Bold, UPPERCASE at call site)

    /// Mono bold 13pt: button labels, prominent tags.
    /// Tracking: +1.4 at call site. Case: .uppercase at call site.
    public static let labelLarge: Font = .bru(.monoBold, size: 13)

    /// Mono bold 11pt: small labels, tags, chips.
    /// Tracking: +1.2 at call site. Case: .uppercase at call site.
    public static let labelSmall: Font = .bru(.monoBold, size: 11)

    /// Mono bold 9pt: micro labels, status badges. Never for anything a
    /// user must read to act; use labelSmall instead.
    /// Tracking: +1.0 at call site. Case: .uppercase at call site.
    public static let labelMicro: Font = .bru(.monoBold, size: 9)

    // MARK: Dynamic Type mapping

    /// The system text style a BRU size scales like. Bands follow the iOS
    /// default (Large) sizes of each style.
    public static func textStyle(forPointSize size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<14:   return .footnote
        case ..<16:   return .subheadline
        case ..<18:   return .body
        case ..<21:   return .title3
        case ..<25:   return .title2
        case ..<31:   return .title
        default:      return .largeTitle
        }
    }
}

// MARK: - Debug Preview

#if DEBUG
#Preview("BRU Type Scale") {
    let roles: [(String, Font, String)] = [
        ("condensedHero",    BRUFont.condensedHero,    "64 / Bebas Neue"),
        ("condensedTitle",   BRUFont.condensedTitle,   "40 / Bebas Neue"),
        ("condensedHeading", BRUFont.condensedHeading, "28 / Bebas Neue"),
        ("condensedLabel",   BRUFont.condensedLabel,   "22 / Bebas Neue"),
        ("displayHero",      BRUFont.displayHero,      "56 / Space Grotesk Bold"),
        ("displayLarge",     BRUFont.displayLarge,     "32 / Space Grotesk Bold"),
        ("displayMedium",    BRUFont.displayMedium,    "18 / Space Grotesk Bold"),
        ("bodyEmphasis",     BRUFont.bodyEmphasis,     "14 / JetBrains Mono Bold"),
        ("bodyDefault",      BRUFont.bodyDefault,      "13 / JetBrains Mono Regular"),
        ("labelLarge",       BRUFont.labelLarge,       "13 / JetBrains Mono Bold"),
        ("labelSmall",       BRUFont.labelSmall,       "11 / JetBrains Mono Bold"),
        ("labelMicro",       BRUFont.labelMicro,       " 9 / JetBrains Mono Bold"),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(roles, id: \.0) { name, font, spec in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bench press 205 lb")
                        .font(font)
                    Text("\(name) · \(spec)")
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
                BRUDivider(.hair)
            }
        }
        .padding()
    }
}
#endif
