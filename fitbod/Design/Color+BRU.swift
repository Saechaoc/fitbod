// Color+BRU.swift
// fitbod
//
// BRU color token documentation and API reference.
// Source of truth: UI-SPEC v2 (commit 4c1674b) § Color, lines 195-206.
//
// IMPLEMENTATION:
//   The 8 Color.bru* static properties are generated automatically by Xcode from
//   fitbod/Assets.xcassets/bru*.colorset entries.
//   Build setting: ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES
//   Generated file: DerivedSources/GeneratedAssetSymbols.swift
//
// TOKEN TABLE (light / dark hex):
//   Color.bruInk     — #0A0A0A / #FAFAF7   — primary text, icons
//   Color.bruPaper   — #FAFAF7 / #0A0A0A   — primary background (inverse of bruInk)
//   Color.bruSignal  — #FF5C1A / #FF7A3D   — accent, CTA, orange
//   Color.bruFaint   — #E8E5DD / #222220   — subtle fills, dividers
//   Color.bruHair    — #D4D0C5 / #2E2C28   — borders, rule lines
//   Color.bruMuted   — #6E6A60 / #9D998E   — secondary text, disabled
//   Color.bruBg      — #F2EFE7 / #16140F   — page background layer 1
//   Color.bruBg2     — #EDEAE0 / #1C1A14   — page background layer 2, cards
//
// All tokens adapt to light/dark mode automatically via the Asset Catalog
// adaptive colorsets in Assets.xcassets/bru*.colorset/Contents.json.
//
// USAGE IN VIEWS:
//   Text("Hello").foregroundStyle(Color.bruInk)
//   Rectangle().fill(Color.bruSignal)
//   .background(Color.bruBg2)

import SwiftUI
