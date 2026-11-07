// PlanCompleteNote.swift
// fitbod
//
// Today's note once an active block is past its last planned week (gap
// B8, missing screen block-plan-complete-prompt). The app never ends a
// block itself (tradeoffs.md "A block past its plan"), so the note stays
// until the lifter ends it, and workouts carry on below it.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
// NO Image(systemName:) / NO .font(.body/.headline/.title*/.caption)

import SwiftUI

struct PlanCompleteNote: View {
    let plannedWeeks: Int
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plannedWeeks == 1
                 ? "The planned week is done."
                 : "All \(plannedWeeks) planned weeks are done.")
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
            Text("End the block to see its review and plan the next one.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
            BRUButton("END BLOCK & REVIEW ▸", kind: .primary, action: onEnd)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.bruBg2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.bruInk).frame(height: 2)
        }
    }
}
