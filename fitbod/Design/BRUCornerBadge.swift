// BRUCornerBadge.swift
// fitbod — Phase 2.1 Plan 03
//
// Tiny labeled badge. Used for "DL" on the week-5 deload ticker cell and
// "PR · e1RM" / "PR · VOL" / "PR · WEIGHT" on session history rows.
//
// Reference: bru-screens/today.jsx line 48-52 (DL badge)
//   position: 'absolute', top: -7, right: -3
//   fontSize: 7, fontWeight: 700, padding: '1px 3px'
//   background: BRU.signal, color: BRU.paper, letterSpacing: 1
//
// USAGE:
//   BRUCornerBadge("DL")
//   BRUCornerBadge("PR", fill: .bruSignal, textColor: .bruPaper)
//   BRUCornerBadge("PR · e1RM")

import SwiftUI

// MARK: - BRUCornerBadge

/// Tiny corner badge with configurable fill and text color.
///
/// Layout:
/// ```
/// ┌──────┐  ← fill color (default: bruSignal)
/// │  DL  │  7pt SpaceGrotesk-Bold, 1pt letterspacing, UPPERCASE
/// └──────┘  1pt horizontal + 3pt horizontal padding
/// ```
///
/// Positioning (overlay vs. absolute):
/// Consumers position the badge via `.overlay(alignment:)` on the parent view.
/// This component does not impose absolute positioning — the consumer decides
/// where to anchor it (top-trailing for the DL ticker badge is the typical use).
///
/// Touch target: badge is not interactive; no hit-area extension required.
public struct BRUCornerBadge: View {

    // MARK: Properties

    private let label: String
    private let fill: Color
    private let textColor: Color

    // MARK: Init

    // NOTE: Color? = nil pattern required — generated Color.bru* tokens are `internal`
    // and cannot appear as default argument values in `public` inits under Swift 6
    // MemberImportVisibility. Nil-coalescing in the body is the canonical workaround.
    public init(_ label: String, fill: Color? = nil, textColor: Color? = nil) {
        self.label = label
        self.fill = fill ?? .bruSignal
        self.textColor = textColor ?? .bruPaper
    }

    // MARK: Body

    public var body: some View {
        Text(label)
            .font(.bru(.grotesk, size: 7))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(textColor)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(fill)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("DL and PR badges") {
    HStack(spacing: 16) {
        // Week-ticker DL badge
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Color.bruFaint)
                .frame(width: 40, height: 32)
                .overlay(
                    Text("W5")
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                )

            BRUCornerBadge("DL")
                .offset(x: 3, y: -7)
        }

        // PR badges on session row
        HStack(spacing: 4) {
            BRUCornerBadge("PR")
            BRUCornerBadge("PR · e1RM")
            BRUCornerBadge("PR · VOL")
            BRUCornerBadge("PR · WEIGHT")
        }

        // Ink-fill variant
        BRUCornerBadge("STR", fill: .bruInk, textColor: .bruPaper)
    }
    .padding()
    .background(Color.bruPaper)
}
#endif
