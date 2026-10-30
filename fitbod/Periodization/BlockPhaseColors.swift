//
//  BlockPhaseColors.swift
//  fitbod
//
//  Phase 04.1 BRU palette per 04-UI-SPEC.md §Phase color palette + 04-UI-REVIEW.md Pillar 3 table
//  — flipped from pre-BRU D-07 teal/amber/orange/slate to BRU tokens.
//

import SwiftUI

public enum BlockPhaseColors {
    // Phase hues with a dark variant in the asset catalog: each keeps its
    // light value and lightens in dark mode, where New Block's cards and
    // phase bands are dark.
    private static let realization = Color("phaseRealization")
    private static let accumulationLabel = Color("phaseAccumulationLabel")
    private static let intensificationLabel = Color("phaseIntensificationLabel")
    private static let peakLabel = Color("phasePeakLabel")
    private static let realizationLabel = Color("phaseRealizationLabel")
    private static let deloadLabel = Color("phaseDeloadLabel")

    public static func color(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            return Color.bruInk
        case .intensification:
            return Color.bruSignal
        case .peak:
            return Color.bruInk.opacity(0.25)
        case .realization:
            return realization.opacity(0.18)
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
            return realization
        case .deload:
            return Color.bruAmber
        }
    }

    /// Contrasting label color for `badgeColor`: `bruOnSignal` near-black on
    /// the signal, green and amber fills, which stay light in both modes,
    /// and `bruPaper` on the blue and plum fills.
    public static func badgeLabelColor(for kind: BlockPhaseKind) -> Color {
        badgeColor(for: kind).bruLabelOnFill
    }

    /// Contrast-safe label ink for phase abbreviations rendered on translucent tinted bands.
    /// Returns a deepened color that passes contrast on a 0.18-opacity band fill, and a
    /// lightened one in dark mode, where the band sits on a dark card.
    /// Distinct from `badgeColor` (which is a vivid fill) — these are darker for legibility.
    public static func phaseLabelInk(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            // Deep indigo #2A52BF, darker than bruBlue's #2F5ACF — passes on 0.18 blue tint.
            return accumulationLabel
        case .intensification:
            // Deep burnt orange #A83000 — passes on 0.18 signal tint, where bruSignalText does not.
            return intensificationLabel
        case .peak:
            // Deepened forest green — passes on 0.18 green tint. Inherited from former .realization identity.
            return peakLabel
        case .realization:
            // Deep plum — passes contrast on 0.18 plum tint band, distinct from .peak forest green.
            return realizationLabel
        case .deload:
            // Deep ochre — passes contrast on bruAmber 0.18 tint (260610-ey9).
            return deloadLabel
        }
    }
}
