//
//  BlockPhaseColors.swift
//  fitbod
//
//  Phase 04.1 BRU palette per 04-UI-SPEC.md §Phase color palette + 04-UI-REVIEW.md Pillar 3 table
//  — flipped from pre-BRU D-07 teal/amber/orange/slate to BRU tokens.
//

import SwiftUI

public enum BlockPhaseColors {
    public static func color(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            return Color.bruInk
        case .intensification:
            return Color.bruSignal
        case .peak:
            return Color.bruInk.opacity(0.25)
        case .realization:
            return Color(red: 122 / 255, green: 60 / 255, blue: 110 / 255).opacity(0.18)
        case .deload:
            return Color.clear
        }
    }

    public static func rowTint(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .intensification:
            return Color.bruSignal.opacity(0.06)
        default:
            return Color.clear
        }
    }

    public static func drawDeloadStripes(ctx: GraphicsContext, rect: CGRect) {
        let stripeWidth: CGFloat = 12
        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: rect.minY))
                p.addLine(to: CGPoint(x: x + 6, y: rect.minY))
                p.addLine(to: CGPoint(x: x + 6 + rect.height, y: rect.maxY))
                p.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
                p.closeSubpath()
            }
            ctx.fill(path, with: .color(Color.bruInk.opacity(0.18)))
            x += stripeWidth
        }
    }

    public static func phaseLabel(_ kind: BlockPhaseKind) -> String {
        kind.rawValue.capitalized
    }

    /// Semantic badge fill color for a phase kind.
    /// Used by phase-row number chip and add-phase-type sheet swatch.
    public static func badgeColor(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            return Color.bruBlue
        case .intensification:
            return Color.bruSignal
        case .peak:
            return Color.bruGreen
        case .realization:
            return Color(red: 122 / 255, green: 60 / 255, blue: 110 / 255)
        case .deload:
            return Color.bruAmber
        }
    }

    /// Contrasting label color for `badgeColor`.
    /// Amber (deload) is light — use bruInk; all others are dark — use white.
    public static func badgeLabelColor(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            return .white
        case .intensification:
            return .white
        case .peak:
            return .white
        case .realization:
            return .white
        case .deload:
            return Color.bruInk
        }
    }

    /// Contrast-safe label ink for phase abbreviations rendered on translucent tinted bands.
    /// Returns a deepened color that passes contrast on a 0.18-opacity band fill.
    /// Distinct from `badgeColor` (which is a vivid fill) — these are darker for legibility.
    public static func phaseLabelInk(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            // bruBlue #2F5ACF is already a deep saturated indigo — passes on 0.18 blue tint.
            return Color.bruBlue
        case .intensification:
            // bruSignal #FF5C1A is burnt orange/rust — passes on 0.18 peach tint.
            return Color.bruSignal
        case .peak:
            // Deepened forest green — passes on 0.18 green tint. Inherited from former .realization identity.
            return Color(red: 34 / 255, green: 96 / 255, blue: 60 / 255)
        case .realization:
            // Deep plum — passes contrast on 0.18 plum tint band, distinct from .peak forest green.
            return Color(red: 78 / 255, green: 38 / 255, blue: 70 / 255)
        case .deload:
            // Deep ochre — passes contrast on bruAmber 0.18 tint. 260610-ey9: deep ochre literal.
            return Color(red: 138 / 255, green: 92 / 255, blue: 24 / 255)
        }
    }
}
