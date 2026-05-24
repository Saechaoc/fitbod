// BRUFont.swift
// fitbod
//
// BRU typography system — 7 semantic type-role tokens via Font.custom.
// Source of truth: UI-SPEC v2 (commit 4c1674b) § Typography, lines 100-160.
//
// USAGE NOTES:
//   - Apply .textCase(.uppercase) at the call site for labelSmall + labelMicro
//     (per UI-SPEC line 686: underlying string stays mixed-case for VoiceOver).
//   - Apply .tracking(n) at the call site — see UI-SPEC letterspacing column.
//   - These are pure Font values; no modifiers are baked in.
//
// POSTSCRIPT NAMES (registered via UIAppFonts in Info.plist):
//   SpaceGrotesk-Bold       — SpaceGrotesk-Bold.ttf
//   SpaceGrotesk-SemiBold   — SpaceGrotesk-SemiBold.ttf
//   JetBrainsMono-Bold      — JetBrainsMono-Bold.ttf
//   JetBrainsMono-Regular   — JetBrainsMono-Regular.ttf

import SwiftUI

// MARK: - BRUFont Namespace

public enum BRUFont {

    // MARK: Display (Space Grotesk Bold)

    /// Display heavy 56pt — hero headlines.
    /// Tracking: -0.5 at call site. Case: as-typed.
    public static let displayHero: Font = .custom("SpaceGrotesk-Bold", size: 56)

    /// Display heavy 32pt — section headers.
    /// Tracking: -0.3 at call site. Case: as-typed.
    public static let displayLarge: Font = .custom("SpaceGrotesk-Bold", size: 32)

    /// Display heavy 18pt — card titles / named labels.
    /// Tracking: 0 at call site. Case: as-typed.
    public static let displayMedium: Font = .custom("SpaceGrotesk-Bold", size: 18)

    // MARK: Body (JetBrains Mono)

    /// Mono bold 14pt — emphasized body copy, primary data values.
    /// Tracking: -0.2 at call site. Case: as-typed.
    public static let bodyEmphasis: Font = .custom("JetBrainsMono-Bold", size: 14)

    /// Mono regular 12pt — secondary data, descriptions.
    /// Tracking: 0 at call site. Case: as-typed.
    public static let bodyDefault: Font = .custom("JetBrainsMono-Regular", size: 12)

    // MARK: Labels (JetBrains Mono Bold — UPPERCASE at call site)

    /// Mono bold 10pt — small labels, tags, chips.
    /// Tracking: +1.2 at call site. Case: .uppercase at call site.
    public static let labelSmall: Font = .custom("JetBrainsMono-Bold", size: 10)

    /// Mono bold 8pt — micro labels, status badges.
    /// Tracking: +1.0 at call site. Case: .uppercase at call site.
    public static let labelMicro: Font = .custom("JetBrainsMono-Bold", size: 8)
}

// MARK: - Debug Preview

#if DEBUG
#Preview("BRU Type Scale") {
    let roles: [(String, Font, String)] = [
        ("displayHero",   BRUFont.displayHero,   "56 / SpaceGrotesk Bold"),
        ("displayLarge",  BRUFont.displayLarge,  "32 / SpaceGrotesk Bold"),
        ("displayMedium", BRUFont.displayMedium, "18 / SpaceGrotesk Bold"),
        ("bodyEmphasis",  BRUFont.bodyEmphasis,  "14 / JetBrains Mono Bold"),
        ("bodyDefault",   BRUFont.bodyDefault,   "12 / JetBrains Mono Regular"),
        ("labelSmall",    BRUFont.labelSmall,    "10 / JetBrains Mono Bold"),
        ("labelMicro",    BRUFont.labelMicro,    " 8 / JetBrains Mono Bold"),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(roles, id: \.0) { name, font, spec in
                VStack(alignment: .leading, spacing: 2) {
                    Text("The quick brown fox")
                        .font(font)
                    Text("\(name) — \(spec)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
        }
        .padding()
    }
}
#endif
