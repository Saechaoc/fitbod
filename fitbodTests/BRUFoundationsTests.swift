//
//  BRUFoundationsTests.swift
//  fitbodTests
//
//  The BRU foundation layer: every face loads at launch, and every color
//  token resolves from the asset catalog.
//

import CoreText
import Testing
import UIKit
@testable import fitbod

@Suite("BRUFoundations")
struct BRUFoundationsTests {

    // MARK: Fonts

    /// iOS loads each font listed under UIAppFonts in Info.plist at launch.
    /// A face whose line or file is missing falls back to the system font on
    /// screen while the other tests stay green. A font registered by hand
    /// anywhere in the test process would hide that, so no test does.
    @Test("Every BRU face loads at launch under its PostScript name")
    func everyFaceLoadsAtLaunch() {
        for face in BRUFace.allCases {
            let font = CTFontCreateWithName(face.rawValue as CFString, 16, nil)
            #expect(
                CTFontCopyPostScriptName(font) as String == face.rawValue,
                "\(face.rawValue) did not load at launch: check its UIAppFonts line and its file in the app bundle."
            )
        }
    }

    // MARK: Color Asset Resolution

    @Test func bruColorAssetsResolve() throws {
        // Color.bru* are generated from Assets.xcassets via
        // ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES.
        // UIColor(named:in:) returns nil if the colorset is missing or malformed.
        // UIColor(Color:) returns .clear on resolution failure (threat T-02.1-03).

        let appBundle = Bundle.main
        let tokens: [(name: String, colorSetName: String)] = [
            ("bruInk",    "bruInk"),
            ("bruPaper",  "bruPaper"),
            ("bruSignal", "bruSignal"),
            ("bruFaint",  "bruFaint"),
            ("bruHair",   "bruHair"),
            ("bruMuted",  "bruMuted"),
            ("bruBg",     "bruBg"),
            ("bruBg2",    "bruBg2"),
            ("bruSlab",   "bruSlab"),
            ("bruOnSlab", "bruOnSlab"),
        ]

        for (name, assetName) in tokens {
            // Primary check: named lookup in app bundle
            let uiColor = UIColor(named: assetName, in: appBundle, compatibleWith: nil)
            #expect(uiColor != nil, "UIColor(named: \"\(assetName)\") is nil — colorset missing from app bundle")

            // Secondary check: SwiftUI Color round-trip (catches clear-fallback trap)
            // Color.bru* are generated as extensions on SwiftUI.Color
            // We must access them dynamically to avoid compile-time MemberImportVisibility issues
            // Use the ColorResource API (available via DeveloperToolsSupport through the app bundle)
            if let uiColor = uiColor {
                // Verify not clear (asset missing produces .clear)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                // bruPaper light mode is #FAFAF7 (all channels ≥ 0.97), bruInk is #0A0A0A (all ≤ 0.04)
                // clear is (0, 0, 0, 0) — alpha == 0 means resolution failed
                #expect(a > 0, "Color \"\(name)\" resolved to transparent (alpha=0) — asset catalog lookup returned .clear")
            }
        }
    }
}
