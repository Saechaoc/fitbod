// PRStripFooter.swift
// fitbod — Phase 2.1 Plan 10
//
// NEW — 3-cell PR summary footer for ExerciseHistoryView.
// UI-SPEC v2 § Component Inventory (line 579 + 614).
//
// Layout:
//   2pt bruInk top rule
//   ┌──────────────┬──────────────┬──────────────────┐
//   │  TOP WEIGHT  │   TOP REPS   │    VOL PR        │  ← VOL PR cell uses bruSignal fill + bruPaper text
//   │    225       │     12       │    4,610         │
//   └──────────────┴──────────────┴──────────────────┘
//   1pt bruInk vertical separators between cells
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

// MARK: - PRStripFooter

/// 3-cell PR summary footer for the exercise history view.
///
/// The "VOL PR" cell uses `bruSignal` fill + `bruPaper` text to highlight
/// the volume personal record — the most actionable of the three PR stats.
/// The other two cells use the default `bruPaper` fill + `bruInk` text.
public struct PRStripFooter: View {
    private let topWeight: String
    private let topReps: String
    private let volPR: String

    public init(topWeight: String, topReps: String, volPR: String) {
        self.topWeight = topWeight
        self.topReps = topReps
        self.volPR = volPR
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)

            HStack(spacing: 0) {
                // TOP WEIGHT cell
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP WEIGHT")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruMuted)
                    Text(topWeight)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bruPaper)

                // Separator
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 1)

                // TOP REPS cell
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP REPS")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruMuted)
                    Text(topReps)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bruPaper)

                // Separator
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 1)

                // VOL PR cell — bruSignal fill + bruPaper text (UI-SPEC line 614)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VOL PR")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruPaper)
                    Text(volPR)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruPaper)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bruSignal)
            }
            .background(Color.bruPaper)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PRStripFooter") {
    VStack(spacing: 0) {
        Spacer()
        PRStripFooter(
            topWeight: "225 lb",
            topReps: "12 @ 175",
            volPR: "4,610"
        )
    }
    .background(Color.bruPaper)
}
#endif
