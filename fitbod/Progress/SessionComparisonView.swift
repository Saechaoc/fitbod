//
//  SessionComparisonView.swift
//  fitbod
//
//  Wave-4 plan 06-07 — 3-column per-exercise diff between the current
//  anchor session and its most-recent intent + sourceRoutineID matching
//  prior session per the corrected D-22 rule (PROG-07 + CONTEXT
//  D-22..D-24).
//
//  ## Layout (Phase 6.1 BRU reskin — 06.1-03)
//
//  BRUHeaderBar(left: "‹ Back", center: "This week vs last week")
//  Column header row (dates + Δ) — BRUFont.labelMicro .bruMuted uppercase
//  BRUDivider(.ink)
//  ScrollView → LazyVStack per-exercise 3-column rows
//
//  Exercise names, this week's column and its date share one left edge.
//
//  ## Δ rendering rules (BRU contract — 06.1-03)
//
//    positive Δ → Color.bruSignal (NOT accentColor)
//    negative Δ → Color.bruMuted (NOT systemRed — regression is data not error)
//                 U+2212 (true minus sign), e.g. "−2.5 kg"
//    zero      → "—" em-dash U+2014, Color.bruMuted
//    nil prior → "{exercise name} — no prior data" single-cell row
//
//  Set weights and weight changes print as logged ("102.5 × 5", "+2.5 lb").
//  An e1RM change rounds to one decimal ("+2.8 e1RM lb"), a whole one
//  shows none ("+5 e1RM lb"), and one that rounds to zero shows "—".
//
//  ## Empty state (UI-SPEC verbatim)
//
//    Heading: "No comparable session"
//    Body:    "Log this routine again next week to compare."
//
//  ## Navigation title
//
//    "This week vs last week" (UI-SPEC verbatim)
//
//  [CITED: CONTEXT D-22/D-23/D-24 + UI-SPEC § SessionComparisonView
//   row styling + PROG-07]
//

import SwiftData
import SwiftUI

public struct SessionComparisonView: View {
    public let anchorSession: Session
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var defaultUnit
    @State private var rows: [SessionComparisonRow] = []
    @State private var didLoad = false

    public init(anchorSession: Session) {
        self.anchorSession = anchorSession
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: "This week vs last week",
                right: nil
            )

            if rows.isEmpty && didLoad {
                emptyState
            } else if !rows.isEmpty {
                columnHeaderRow
                BRUDivider(.ink)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.exerciseID) { index, row in
                            rowView(row)
                            if index < rows.count - 1 {
                                BRUDivider(.hair)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            rows = SessionComparator.compare(current: anchorSession, context: ctx)
            didLoad = true
        }
    }

    // MARK: - Column Header Row

    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            Text(thisWeekDateLabel.uppercased())
                .font(BRUFont.labelMicro)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Δ")
                .font(BRUFont.labelMicro)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(lastWeekDateLabel.uppercased())
                .font(BRUFont.labelMicro)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bruPaper)
    }

    private var thisWeekDateLabel: String {
        anchorSession.startedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private var lastWeekDateLabel: String {
        if let firstPrior = rows.first(where: { $0.lastWeekTopSet != nil })?.lastWeekTopSet {
            return firstPrior.sessionStartedAt.formatted(.dateTime.month(.abbreviated).day())
        }
        return "—"
    }

    // MARK: - Per-Row Body

    @ViewBuilder
    private func rowView(_ row: SessionComparisonRow) -> some View {
        if row.lastWeekTopSet == nil {
            // No prior data — single-cell inline row
            HStack(spacing: 16) {
                Text("\(row.exerciseName) — no prior data")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // 3-column layout: this-week | Δ | last-week
            HStack(spacing: 8) {
                // Leading (~35%) — exercise name + this-week value, on the
                // same left edge as every other row's name
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.exerciseName)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    if let top = row.thisWeekTopSet {
                        Text("\(Self.formatWeight(top.weight)) × \(top.reps)")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center (~30%) — Δ values
                VStack(spacing: 2) {
                    let unitLabel = unit(for: row.exerciseID).rawValue
                    deltaView(value: row.deltaWeight, unit: unitLabel, format: Self.formatWeight)
                    deltaViewReps(value: row.deltaReps)
                    deltaView(value: row.deltaE1RM, unit: "e1RM \(unitLabel)", format: Self.formatE1RMChange)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Trailing (~35%) — last-week value
                VStack(alignment: .leading, spacing: 2) {
                    if let top = row.lastWeekTopSet {
                        Text("\(Self.formatWeight(top.weight)) × \(top.reps)")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// The exercise's own unit wins over the app-wide one.
    private func unit(for exerciseID: UUID) -> WeightUnit {
        let exercise = (anchorSession.exercises ?? [])
            .first { $0.exercise?.id == exerciseID }?
            .exercise
        return .effective(for: exercise, default: defaultUnit)
    }

    // MARK: - Δ Rendering

    /// `format` writes the size of the change. A change it writes as zero,
    /// such as an e1RM change under 0.05, is no change.
    @ViewBuilder
    private func deltaView(value: Double?, unit: String, format: (Double) -> String) -> some View {
        if let v = value {
            let shown = format(abs(v))
            if shown == format(0) {
                // Zero Δ: em-dash U+2014 in bruMuted (bruFaint is a fill, too light for text)
                BRUDisplay("\u{2014}", size: .medium, color: .bruMuted)
                    .accessibilityLabel("No change")
            } else if v > 0 {
                BRUDisplay("+\(shown) \(unit)", size: .medium, color: .bruSignal)
            } else {
                // U+2212 minus sign (NOT U+002D hyphen) — preserved per BRU contract
                BRUDisplay("\u{2212}\(shown) \(unit)", size: .medium, color: .bruMuted)
            }
        } else {
            BRUDisplay("\u{2014}", size: .medium, color: .bruMuted)
                .accessibilityLabel("No earlier set")
        }
    }

    @ViewBuilder
    private func deltaViewReps(value: Int?) -> some View {
        if let v = value {
            if v > 0 {
                BRUDisplay("+\(BRUCountLabel.text(v, "rep"))", size: .medium, color: .bruSignal)
            } else if v < 0 {
                // U+2212 minus sign (NOT hyphen)
                BRUDisplay("\u{2212}\(BRUCountLabel.text(abs(v), "rep"))", size: .medium, color: .bruMuted)
            } else {
                BRUDisplay("\u{2014}", size: .medium, color: .bruMuted)
                    .accessibilityLabel("No change in reps")
            }
        } else {
            BRUDisplay("\u{2014}", size: .medium, color: .bruMuted)
                .accessibilityLabel("No earlier set")
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No comparable session")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Log this routine again next week to compare.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formatting

    /// A set weight or a weight change as logged, such as "102.25".
    static func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    /// An e1RM change to one decimal, halves away from zero, such as "3.2"
    /// for 3.16667, and a whole one without, such as "5". The estimate
    /// keeps every digit of its formula, which "%g" would print.
    static func formatE1RMChange(_ value: Double) -> String {
        formatWeight((value * 10).rounded() / 10)
    }
}
