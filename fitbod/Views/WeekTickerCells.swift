// WeekTickerCells.swift
// fitbod — Phase 2.1 Plan 04
//
// 5-cell W1-W5 week ticker strip used inside BlockContextBand.
// Reference: bru-screens/today.jsx lines 32-56
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI

// MARK: - WeekTickerCells

/// A horizontal row of W1…Wn cells representing the block's week strip.
///
/// Visual states per today.jsx:
/// - Active (n == currentWeek): bruInk fill + bruPaper text
/// - Past (n < currentWeek): bruFaint fill + bruInk text + no border
/// - Future (n > currentWeek): transparent fill + 1.5pt bruInk outline + bruInk text
/// - Deload week: BRUCornerBadge("DL") top-right overlay (any state)
///
/// Cell height: 28pt. Width: flex (equal). Gap: 4pt between cells.
public struct WeekTickerCells: View {

    // MARK: - Properties

    let currentWeek: Int          // 1-based, e.g. 3
    let totalWeeks: Int           // total count, e.g. 5
    let deloadWeeks: Set<Int>     // which week indices (1-based) are deload weeks

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(totalWeeks, 1), id: \.self) { n in
                cell(for: n)
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(for n: Int) -> some View {
        let isActive = n == currentWeek
        let isPast = n < currentWeek
        // future: n > currentWeek

        ZStack(alignment: .topTrailing) {
            // Cell background + border
            Rectangle()
                .fill(cellFill(isActive: isActive, isPast: isPast))
                .overlay(
                    Rectangle()
                        .stroke(
                            isActive || isPast ? Color.clear : Color.bruInk,
                            lineWidth: 1.5
                        )
                )
                .frame(maxWidth: .infinity, minHeight: 28)

            // Week label centered
            Text("W\(n)")
                .font(.custom("SpaceGrotesk-Bold", size: 16))
                .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                .frame(maxWidth: .infinity, minHeight: 28)

            // DL corner badge — above the cell, offset top-right per today.jsx lines 48-52
            if deloadWeeks.contains(n) {
                BRUCornerBadge("DL")
                    .offset(x: 3, y: -7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28)
    }

    // MARK: - Helpers

    private func cellFill(isActive: Bool, isPast: Bool) -> Color {
        if isActive { return .bruInk }
        if isPast   { return .bruFaint }
        return .clear
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WeekTickerCells — W3 active, W5 deload") {
    VStack(spacing: 16) {
        // Standard 5-week block, on week 3, week 5 is deload
        WeekTickerCells(currentWeek: 3, totalWeeks: 5, deloadWeeks: [5])
            .padding(.horizontal, 16)

        // Week 1 active (just started)
        WeekTickerCells(currentWeek: 1, totalWeeks: 4, deloadWeeks: [4])
            .padding(.horizontal, 16)

        // All past — week 5 of 5
        WeekTickerCells(currentWeek: 5, totalWeeks: 5, deloadWeeks: [5])
            .padding(.horizontal, 16)
    }
    .padding(.vertical, 16)
    .background(Color.bruPaper)
}
#endif
