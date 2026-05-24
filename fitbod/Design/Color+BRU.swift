// Color+BRU.swift
// fitbod
//
// BRU color token definitions — accessible from both the fitbod app target
// and the FitbodWidgetsExtension target.
//
// Source of truth: UI-SPEC v2 (commit 4c1674b) § Color, lines 195-206.
//
// IMPLEMENTATION NOTES:
//   Colors are defined here via Color("name") lookups against the shared
//   Assets.xcassets colorset entries, making them available to any target
//   that includes this file (app + widget extension).
//
//   The Xcode build setting ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
//   also generates internal Color.bru* extensions in the main app's DerivedSources.
//   Those generated extensions are `internal` and only available inside the fitbod
//   module — they are NOT re-exported to the widget extension. The definitions below
//   are the canonical cross-target API.
//
//   Default argument values in public inits must use these extensions, not the
//   generated ones, to satisfy Swift 6 MemberImportVisibility. Pattern:
//     public init(color: Color = .bruInk)   ← references THIS file's public extension
//
// TOKEN TABLE (light / dark hex):
//   Color.bruInk     — #0A0A0A / #FAFAF7   — borders, body text, dominant dark surface
//   Color.bruPaper   — #FAFAF7 / #0A0A0A   — dominant light surface, text on ink
//   Color.bruSignal  — #FF5C1A / #FF7A3D   — accent, CTAs, upward trends
//   Color.bruFaint   — #E8E5DD / #222220   — completed/deemphasized fills
//   Color.bruHair    — #D4D0C5 / #2E2C28   — 1pt list-row dividers only
//   Color.bruMuted   — #6E6A60 / #9D998E   — secondary text, captions, metadata
//   Color.bruBg      — #F2EFE7 / #16140F   — screen-edge chrome, status bar background
//   Color.bruBg2     — #EDEAE0 / #1C1A14   — inset cards, calibration meter backing
//
// All tokens adapt to light/dark mode via adaptive colorsets in Assets.xcassets.
//
// USAGE IN VIEWS:
//   Text("Hello").foregroundStyle(Color.bruInk)
//   Rectangle().fill(Color.bruSignal)
//   .background(Color.bruBg2)

import SwiftUI

// MARK: - BRU Color Extensions

public extension Color {
    /// Near-black `#0A0A0A` (light) / `#FAFAF7` (dark).
    /// Borders, body text, icon fills. Dominant surface in dark mode.
    static let bruInk: Color = Color("bruInk")

    /// Warm off-white `#FAFAF7` (light) / `#0A0A0A` (dark).
    /// Dominant surface, text on ink backgrounds.
    static let bruPaper: Color = Color("bruPaper")

    /// Burnt orange `#FF5C1A` (light) / `#FF7A3D` (dark).
    /// Single accent role — CTAs, PR badges, upward trend indicators.
    static let bruSignal: Color = Color("bruSignal")

    /// Recessed fill `#E8E5DD` (light) / `#222220` (dark).
    /// Completed/past ticker cells, deemphasized filled areas.
    static let bruFaint: Color = Color("bruFaint")

    /// Hairline separator `#D4D0C5` (light) / `#2E2C28` (dark).
    /// 1pt list-row dividers ONLY. Always 1pt height.
    static let bruHair: Color = Color("bruHair")

    /// Mid-warm gray `#6E6A60` (light) / `#9D998E` (dark).
    /// Secondary text: subtitles, captions, metadata, drag handles.
    static let bruMuted: Color = Color("bruMuted")

    /// Screen-edge warm background `#F2EFE7` (light) / `#16140F` (dark).
    /// Status-bar background, bottom safe-area fillers.
    static let bruBg: Color = Color("bruBg")

    /// Inset card background `#EDEAE0` (light) / `#1C1A14` (dark).
    /// Weekly tonnage spark backing, calibration meter cards.
    static let bruBg2: Color = Color("bruBg2")
}
