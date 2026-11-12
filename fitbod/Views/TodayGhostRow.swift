// TodayGhostRow.swift
// fitbod
//
// A quiet full-width row on Today that opens a secondary route, such as
// "Choose another session ›" under the exercise list (RM-006), or expands
// in place, as Show all does. It carries no signal colour, so the hero's
// button stays the one loud action on the page.

import SwiftUI

struct TodayGhostRow: View {
    let title: String
    /// "›" opens a screen; a row that expands in place passes "▾", or "▴" while open (iconography.md).
    var glyph = "›"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(glyph)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
            // The exercise row above closes with its own hair rule.
            .overlay(alignment: .bottom) { Rectangle().fill(Color.bruHair).frame(height: 1) }
        }
        .buttonStyle(.bruRow)
    }
}

#if DEBUG
#Preview("TodayGhostRow") {
    TodayGhostRow(title: "Choose another session", action: {})
        .background(Color.bruPaper)
}
#endif
