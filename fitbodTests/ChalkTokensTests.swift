//
//  ChalkTokensTests.swift
//  fitbodTests
//
//  Chalkline design-system guards:
//    - every text/background pair the system uses clears WCAG AA (4.5:1)
//      in light, dark and Increase Contrast — so a palette tweak that
//      breaks legibility fails CI instead of shipping;
//    - the accent fill clears 3:1 against paper (WCAG 1.4.11, UI parts);
//    - the shared number formatters produce the strings the screens and
//      docs show.
//

import Foundation
import Testing
@testable import fitbod

@Suite("Chalkline tokens")
struct ChalkTokensTests {

    // MARK: - Contrast

    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((hex >> 16) & 0xFF)
        let g = channel((hex >> 8) & 0xFF)
        let b = channel(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// (foreground, background, label) pairs that carry text.
    private static let textPairs: [(ChalkPalette.Token, ChalkPalette.Token, String)] = [
        (ChalkPalette.ink, ChalkPalette.canvas, "ink/canvas"),
        (ChalkPalette.ink, ChalkPalette.surface, "ink/surface"),
        (ChalkPalette.ink, ChalkPalette.sunken, "ink/sunken"),
        (ChalkPalette.ink, ChalkPalette.complete, "ink/complete"),
        (ChalkPalette.ink2, ChalkPalette.canvas, "ink2/canvas"),
        (ChalkPalette.ink2, ChalkPalette.surface, "ink2/surface"),
        (ChalkPalette.ink2, ChalkPalette.complete, "ink2/complete"),
        (ChalkPalette.ink3, ChalkPalette.canvas, "ink3/canvas"),
        (ChalkPalette.ink3, ChalkPalette.surface, "ink3/surface"),
        (ChalkPalette.ink3, ChalkPalette.sunken, "ink3/sunken"),
        (ChalkPalette.onPanel, ChalkPalette.panel, "onPanel/panel"),
        (ChalkPalette.onPanel, ChalkPalette.panelRaised, "onPanel/panelRaised"),
        (ChalkPalette.onPanel2, ChalkPalette.panel, "onPanel2/panel"),
        (ChalkPalette.accentOnPanel, ChalkPalette.panel, "accentOnPanel/panel"),
        (ChalkPalette.onAccent, ChalkPalette.accent, "onAccent/accent"),
        (ChalkPalette.accentInk, ChalkPalette.canvas, "accentInk/canvas"),
        (ChalkPalette.accentInk, ChalkPalette.surface, "accentInk/surface"),
        (ChalkPalette.danger, ChalkPalette.canvas, "danger/canvas"),
        (ChalkPalette.danger, ChalkPalette.surface, "danger/surface"),
    ]

    @Test("every text pair is at least 4.5:1 in light, dark and Increase Contrast")
    func textContrast() {
        for (fg, bg, label) in Self.textPairs {
            for dark in [false, true] {
                for highContrast in [false, true] {
                    let ratio = Self.contrast(
                        fg.hex(dark: dark, highContrast: highContrast),
                        bg.hex(dark: dark, highContrast: highContrast)
                    )
                    #expect(ratio >= 4.5, "\(label) dark=\(dark) HC=\(highContrast): \(ratio)")
                }
            }
        }
    }

    @Test("the accent fill is at least 3:1 against paper")
    func accentFillContrast() {
        for dark in [false, true] {
            for surface in [ChalkPalette.canvas, ChalkPalette.surface] {
                let ratio = Self.contrast(ChalkPalette.accent.hex(dark: dark, highContrast: false), surface.hex(dark: dark, highContrast: false))
                #expect(ratio >= 3, "accent on paper dark=\(dark): \(ratio)")
            }
        }
    }

    @Test("Increase Contrast never lowers a secondary ink's contrast")
    func highContrastIsStronger() {
        for token in [ChalkPalette.ink2, ChalkPalette.ink3] {
            for dark in [false, true] {
                let normal = Self.contrast(token.hex(dark: dark, highContrast: false), ChalkPalette.canvas.hex(dark: dark, highContrast: false))
                let high = Self.contrast(token.hex(dark: dark, highContrast: true), ChalkPalette.canvas.hex(dark: dark, highContrast: true))
                #expect(high >= normal)
            }
        }
    }

    // MARK: - Formatting

    @Test("durations, clocks, weights, RPE and volume")
    func formatting() {
        #expect(ChalkFormat.duration(seconds: 180) == "3:00")
        #expect(ChalkFormat.duration(seconds: 45) == "0:45")
        #expect(ChalkFormat.duration(seconds: -5) == "0:00")
        #expect(ChalkFormat.clock(seconds: 1934) == "32:14")
        #expect(ChalkFormat.clock(seconds: 4154) == "1:09:14")
        #expect(ChalkFormat.weight(185) == "185")
        #expect(ChalkFormat.weight(187.5) == "187.5")
        #expect(ChalkFormat.weight(2.25) == "2.25")
        #expect(ChalkFormat.weight(-20) == "-20")
        #expect(ChalkFormat.rpe(8) == "8")
        #expect(ChalkFormat.rpe(8.5) == "8.5")
        #expect(ChalkFormat.volume(31_400) == "31.4K")
        #expect(ChalkFormat.volume(125_000) == "125K")
    }

    @Test("the set table needs 320 pt at default text — and fits a 375 pt iPhone row")
    @MainActor
    func setTableBudget() {
        // Default (Large) widths from SetTableMetrics: set 28, previous ≥ 44,
        // weight 74, reps 54, RPE 42, check 48, five 6 pt gaps.
        let required: CGFloat = 28 + 44 + 74 + 54 + 42 + Chalk.Size.setCheck + 5 * SetTableMetrics.spacing
        #expect(required == 320)
        // iPhone SE: 375 − 2 × 16 (inset-grouped section margin) − row insets.
        let insets = SessionExerciseCard.tableRowInsets
        let available = 375 - 32 - insets.leading - insets.trailing
        #expect(available >= required)
    }
}
