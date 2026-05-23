//
//  DeloadSignalDetailSheet.swift
//  fitbod
//
//  Phase 5 PROG-06 — sheet listing each fired DeloadSignal with
//  numeric values. Presented from DeloadAdvisoryBanner.onTapBody.
//
//  Presentation: medium + large detents (medium default); navigation
//  title "Fatigue Signals"; Done toolbar button.
//
//  UI-SPEC §Copywriting Contract verbatim row labels + values + the
//  advisory-only footer "This is an advisory. Block schedule is
//  canonical — deload when you decide, not automatically."
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
            List {
                Section {
                    ForEach(report.firedSignals, id: \.self) { signal in
                        HStack {
                            Text(label(for: signal))
                                .font(.body)
                            Spacer()
                            Text(value(for: signal))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } footer: {
                    Text("This is an advisory. Block schedule is canonical — deload when you decide, not automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fatigue Signals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func label(for signal: DeloadSignal) -> String {
        switch signal {
        case .e1RMDrop:         return "e1RM drop"
        case .rpeCreep:         return "RPE creep"
        case .missedTopOfRange: return "Missed rep range"
        }
    }

    private func value(for signal: DeloadSignal) -> String {
        switch signal {
        case .e1RMDrop(let p):
            return "\(Int((p * 100).rounded()))% drop over last 3 vs prior 3 sessions"
        case .rpeCreep(let amount, let name, let intent):
            let rounded = String(format: "%.1f", amount)
            return "+\(rounded) RPE at same load (\(name), \(intent.rawValue))"
        case .missedTopOfRange(let r):
            return "\(Int((r * 100).rounded()))% of sets missed target reps"
        }
    }
}
