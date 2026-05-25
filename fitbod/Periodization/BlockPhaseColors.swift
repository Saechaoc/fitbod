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
        case .realization:
            return Color.bruInk.opacity(0.25)
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
}
