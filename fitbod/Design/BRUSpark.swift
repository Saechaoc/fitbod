// BRUSpark.swift
// fitbod — Phase 2.1 Plan 03
//
// Canvas-drawn 8-bar mini-chart. Used in SessionHistoryView for weekly tonnage.
//
// Reference: bru-screens/session-history.jsx line 38-48
//   background: BRU.bg2, border: `1.5px solid ${BRU.ink}`, padding: 6
//   bars: flex: 1, height: `${v}%`, background: i === 7 ? BRU.signal : BRU.ink
//
// USAGE:
//   BRUSpark(values: [58, 62, 64, 61, 66, 68, 70, 71])
//   BRUSpark(values: weeklyTonnages, highlightTrailing: true)
//       .frame(width: 80, height: 32)

import SwiftUI

// MARK: - BRUSpark

/// 8-bar mini-chart drawn via `Canvas`. Equal-width bars, 4pt gaps.
///
/// - The trailing bar (index `n-1`) renders in `Color.bruSignal` when
///   `highlightTrailing` is true — visualizing the most-recent week.
/// - All other bars render in `Color.bruInk`.
/// - A zero value draws a short `Color.bruMuted` stub, so every slot stays
///   visible and one real bar never floats alone in an empty box. A small
///   real value never draws shorter than the stub.
/// - Background: `Color.bruBg2`. Outer border: 1.5pt `Color.bruInk`, with
///   the bars inset 6pt from it, as in the reference.
///
/// Height comes from the parent frame. Typical use: `.frame(width: 80, height: 32)`.
/// The bars are bottom-aligned; proportional to `values.max()`.
public struct BRUSpark: View {

    // MARK: Properties

    private let values: [Double]
    private let highlightTrailing: Bool

    // MARK: Init

    public init(values: [Double], highlightTrailing: Bool = true) {
        self.values = values
        self.highlightTrailing = highlightTrailing
    }

    // MARK: Body

    public var body: some View {
        Canvas { ctx, size in
            let n = values.count
            guard n > 0 else { return }

            let maxV = values.max() ?? 0
            let gap: CGFloat = 4
            let barW = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            let stub = min(Self.stubHeight, size.height)

            for (i, v) in values.enumerated() {
                let isEmpty = v <= 0 || maxV <= 0
                let h = isEmpty ? stub : max(stub, size.height * CGFloat(v / maxV))
                let isTrailing = (i == n - 1) && highlightTrailing
                let color: Color = isEmpty ? .bruMuted : (isTrailing ? .bruSignal : .bruInk)
                let rect = CGRect(
                    x: CGFloat(i) * (barW + gap),
                    y: size.height - h,
                    width: barW,
                    height: h
                )
                ctx.fill(Path(rect), with: .color(color))
            }
        }
        .padding(6)
        .background(Color.bruBg2)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1.5)
        )
    }

    /// Height of the stub a zero value draws.
    private static let stubHeight: CGFloat = 2
}

// MARK: - Previews

#if DEBUG
#Preview("8-week tonnage sample") {
    VStack(spacing: 16) {
        Text("BRUSpark")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        // The 8-week sample from the plan spec
        BRUSpark(values: [58, 62, 64, 61, 66, 68, 70, 71])
            .frame(width: 100, height: 40)

        // Flat line (all equal)
        BRUSpark(values: [50, 50, 50, 50, 50, 50, 50, 50])
            .frame(width: 100, height: 40)

        // No trailing highlight
        BRUSpark(values: [58, 62, 64, 61, 66, 68, 70, 71], highlightTrailing: false)
            .frame(width: 100, height: 40)

        // Sparse: empty weeks keep their stubs
        BRUSpark(values: [0, 0, 0, 12, 0, 0, 0, 58])
            .frame(width: 100, height: 40)
    }
    .padding()
    .background(Color.bruPaper)
}
#endif
