//
//  DeloadSignalDetailSheet.swift
//  fitbod
//
//  Phase 5.1 Plan 03 — BRU reskin of the advisory tap-through detail sheet.
//
//  Chrome: BRUHeaderBar(left: nil, center: "Fatigue Signals", right: "DONE")
//  Body:   LazyVStack of signalRow() helpers separated by BRUDivider(.hair)
//  Footer: UI-SPEC §Copywriting Contract verbatim advisory disclaimer
//  Detents: [.medium, .large] — preserved from Phase 5 baseline
//
//  Signal row layout per UI-SPEC §DeloadSignalDetailSheet copy table:
//    HStack(alignment: .top)
//      VStack(alignment: .leading, spacing: 4)
//        label  — labelSmall, bruMuted
//        value  — bodyDefault, bruInk
//      Spacer()
//    .padding(.horizontal, 16).padding(.vertical, 12)
//
//  Signal label + value copy (verbatim, D-16 locked):
//    e1RM drop        / "{N}% drop over last 3 vs prior 3 sessions"
//    RPE creep        / "+{x.x} RPE at same load ({exercise}, {intent})"
//    Missed rep range / "{N}% of sets missed target reps"
//  Only fired signals render — inactive signals NOT shown.
//
//  Footer copy (UI-SPEC §Copywriting Contract line 348, verbatim):
//    "This is an advisory. Block schedule is canonical — deload when you decide, not automatically."
//
//  Public init UNCHANGED: (report: DeloadSignalReport)
//
//  BRU contract — ZERO banned tokens:
//    No Color.accentColor, Color(.system*), RoundedRectangle(cornerRadius:),
//    Capsule(), .font(.body|.headline|.caption|.subheadline|.footnote),
//    Image(systemName:), .navigationTitle(
//

import SwiftUI

public struct DeloadSignalDetailSheet: View {
    public let report: DeloadSignalReport
    @Environment(\.dismiss) private var dismiss

    public init(report: DeloadSignalReport) {
        self.report = report
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar(
                    left: nil,
                    center: "Fatigue Signals",
                    right: HeaderAction("DONE") { dismiss() }
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Render only fired signals in order: e1RM → RPE → missed reps
                        ForEach(report.firedSignals, id: \.self) { signal in
                            signalRow(
                                label: labelText(for: signal),
                                value: valueText(for: signal)
                            )
                            BRUDivider(.hair)
                        }

                        // Footer — UI-SPEC §Copywriting Contract line 348 verbatim
                        Text("This is an advisory. Block schedule is canonical — deload when you decide, not automatically.")
                            .font(BRUFont.labelMicro)
                            .tracking(1.0)
                            .foregroundStyle(Color.bruMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Row builder

    @ViewBuilder
    private func signalRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Text(value)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Verbatim copy helpers (D-16 locked)

    private func labelText(for signal: DeloadSignal) -> String {
        switch signal {
        case .e1RMDrop:         return "e1RM drop"
        case .rpeCreep:         return "RPE creep"
        case .missedTopOfRange: return "Missed rep range"
        }
    }

    private func valueText(for signal: DeloadSignal) -> String {
        switch signal {
        case .e1RMDrop(let percentDrop):
            return "\(Int((percentDrop * 100).rounded()))% drop over last 3 vs prior 3 sessions"
        case .rpeCreep(let amount, let exerciseName, let intent):
            let rounded = String(format: "%.1f", amount)
            return "+\(rounded) RPE at same load (\(exerciseName), \(intent.rawValue))"
        case .missedTopOfRange(let missRatio):
            return "\(Int((missRatio * 100).rounded()))% of sets missed target reps"
        }
    }
}
