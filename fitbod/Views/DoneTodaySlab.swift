// DoneTodaySlab.swift
// fitbod
//
// Today once today's workout is finished (design map: today-workout-done).
// It takes the NEXT slab's place: the finished workout with a way to its
// summary, and the session that comes next as upcoming rather than a fresh
// START WORKOUT ▸.
//
// ┌──────────────────────────────────────────────┐  ← bruInk
// │  DONE TODAY                                  │
// │  Push A                                      │  hero
// │  15 SETS · 55M · 4,230 LB                    │
// │  UP NEXT · PULL A · WED                      │
// │  [            VIEW WORKOUT ›            ]    │  paper outline
// │             CHOOSE A SESSION ›               │  with a block only
// └──────────────────────────────────────────────┘
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

public struct DoneTodaySlab: View {
    let session: Session
    /// The next session, such as "Pull A · Wed"; nil with no block.
    let upNext: String?
    let unit: WeightUnit
    let onView: @MainActor () -> Void
    /// Opens the block's sessions, to train again; nil with no block.
    let onChooseSession: (@MainActor () -> Void)?

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Done today")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper.opacity(0.6))

            Spacer().frame(height: 6)
            BRUDisplay(session.displayName, size: .hero, color: .bruPaper)
            Spacer().frame(height: 12)

            Text(metaLine)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper)
                .fixedSize(horizontal: false, vertical: true)

            if let upNext {
                Text("Up next · \(upNext)")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .accessibilityIdentifier("doneToday.upNext")
            }

            Spacer().frame(height: 16)

            // Paper outline on the ink slab, as the resume slab's DISCARD.
            Button(action: onView) {
                Text("View workout ›")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(Rectangle().stroke(Color.bruPaper, lineWidth: 1.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("doneToday.view")

            if let onChooseSession {
                Button(action: onChooseSession) {
                    Text("Choose a session ›")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruPaper.opacity(0.8))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("doneToday.choose")
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "15 SETS · 55M · 4,230 LB": what the workout logged.
    private var metaLine: String {
        var parts = [BRUCountLabel.text(session.loggedSetCount, "set")]
        if let seconds = session.totalDurationSeconds {
            parts.append(SessionHistoryFormat.duration(minutes: seconds / 60))
        }
        let tonnage = SessionHistoryFormat.tonnage(of: session)
        if tonnage > 0 {
            parts.append("\(SessionHistoryFormat.compactTonnage(tonnage)) \(unit.rawValue)")
        }
        return parts.joined(separator: " · ")
    }
}
