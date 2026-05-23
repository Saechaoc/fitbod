//
//  SessionComparisonView.swift
//  fitbod
//
//  Wave-4 plan 06-07 — 3-column per-exercise diff between the current
//  anchor session and its most-recent intent + sourceRoutineID matching
//  prior session per the corrected D-22 rule (PROG-07 + CONTEXT
//  D-22..D-24).
//
//  ## Layout (UI-SPEC § SessionComparisonView row styling lines
//  540–552)
//
//  Column-header row above the list:
//
//      {this-week-date}  |  Δ  |  {last-week-date}
//      .caption .secondaryLabel
//
//  Per-row 3-column HStack:
//
//      this-week .body (~35%)  |  Δ.headline (~30%)  |  last-week .body (~35%)
//
//  ## Δ rendering rules (UI-SPEC item 27)
//
//    positive Δ → Color.accentColor .headline ("+5 kg / +1 rep / +3 kg")
//    negative Δ → Color(.secondaryLabel) .headline (NOT systemRed) using
//                 U+2212 (true minus sign), e.g. "−2.5 kg"
//    zero      → "—" em-dash, Color(.tertiaryLabel)
//    nil prior → "{exercise name} — no prior data" single-cell row
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
    @State private var rows: [SessionComparisonRow] = []
    @State private var didLoad = false

    public init(anchorSession: Session) {
        self.anchorSession = anchorSession
    }

    public var body: some View {
        Group {
            if rows.isEmpty && didLoad {
                emptyState
            } else if !rows.isEmpty {
                List {
                    Section(header: columnHeader) {
                        ForEach(rows, id: \.exerciseID) { row in
                            rowView(row)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("This week vs last week")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            rows = SessionComparator.compare(current: anchorSession, context: ctx)
            didLoad = true
        }
    }

    // MARK: - Column header

    private var columnHeader: some View {
        HStack {
            Text(anchorSession.startedAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Δ")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(priorDateLabel)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var priorDateLabel: String {
        if let firstPrior = rows.first(where: { $0.lastWeekTopSet != nil })?.lastWeekTopSet {
            return firstPrior.sessionStartedAt.formatted(.dateTime.month(.abbreviated).day())
        }
        return "—"
    }

    // MARK: - Per-row body

    @ViewBuilder
    private func rowView(_ row: SessionComparisonRow) -> some View {
        if row.thisWeekTopSet == nil && row.lastWeekTopSet == nil {
            HStack {
                Text("\(row.exerciseName) — no prior data")
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        } else if row.lastWeekTopSet == nil {
            HStack {
                Text("\(row.exerciseName) — no prior data")
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.exerciseName)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                HStack(spacing: 8) {
                    leftCell(top: row.thisWeekTopSet)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    centerCell(row: row)
                        .frame(maxWidth: .infinity, alignment: .center)
                    rightCell(top: row.lastWeekTopSet)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func leftCell(top: TopSetSummary?) -> some View {
        if let t = top {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatWeight(t.weight)) kg × \(t.reps)")
                    .font(.body)
                if let e1rm = t.e1RM {
                    Text("e1RM \(Int(e1rm.rounded())) kg")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        } else {
            Text("—")
                .font(.body)
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    @ViewBuilder
    private func rightCell(top: TopSetSummary?) -> some View {
        if let t = top {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatWeight(t.weight)) kg × \(t.reps)")
                    .font(.body)
                if let e1rm = t.e1RM {
                    Text("e1RM \(Int(e1rm.rounded())) kg")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        } else {
            Text("—")
                .font(.body)
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }

    @ViewBuilder
    private func centerCell(row: SessionComparisonRow) -> some View {
        VStack(spacing: 2) {
            deltaText(value: row.deltaWeight, unit: "kg")
            deltaTextReps(value: row.deltaReps)
            deltaText(value: row.deltaE1RM, unit: "e1RM kg")
        }
    }

    // MARK: - Δ rendering

    private func deltaText(value: Double?, unit: String) -> some View {
        let txt: Text
        let color: Color
        if let v = value {
            if v > 0 {
                txt = Text("+\(formatWeight(v)) \(unit)")
                color = Color.accentColor
            } else if v < 0 {
                // U+2212 minus sign (not hyphen)
                txt = Text("−\(formatWeight(abs(v))) \(unit)")
                color = Color(.secondaryLabel)
            } else {
                txt = Text("—")
                color = Color(.tertiaryLabel)
            }
        } else {
            txt = Text("—")
            color = Color(.tertiaryLabel)
        }
        return txt
            .font(.headline)
            .foregroundStyle(color)
    }

    private func deltaTextReps(value: Int?) -> some View {
        let txt: Text
        let color: Color
        if let v = value {
            if v > 0 {
                txt = Text("+\(v) reps")
                color = Color.accentColor
            } else if v < 0 {
                txt = Text("−\(abs(v)) reps")
                color = Color(.secondaryLabel)
            } else {
                txt = Text("—")
                color = Color(.tertiaryLabel)
            }
        } else {
            txt = Text("—")
            color = Color(.tertiaryLabel)
        }
        return txt
            .font(.headline)
            .foregroundStyle(color)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("No comparable session")
                .font(.headline)
            Text("Log this routine again next week to compare.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Formatting

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}
