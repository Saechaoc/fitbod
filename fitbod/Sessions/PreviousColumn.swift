// PreviousColumn.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 42).
// UI-SPEC v2 § Session logger line 545 + 580.
//
// The inline "Previous" column rendered between the "Set N" label and the
// weight cell on every SetRow. Surfaces the most recent matching-intent prior
// set for the exercise.
//
// UI-SPEC verbatim format:
//   Populated:   "{w} × {r} @ {rpe} (MON)"   — BRUFont.bodyDefault mono bruMuted
//   Empty:       "—"                           — BRUFont.bodyDefault mono bruMuted
//   Other-intent fallback: "{w} × {r} (OTHER)" italic
//
// The query is delegated to PreviousMatchingIntent.fetchTopWorkingSet —
// the shared helper introduced in plan 01-01. Fires ONCE per row in .task,
// cached in @State and read on subsequent re-renders.
//
// BRU contract:
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct PreviousColumn: View {
    @Environment(\.modelContext) private var ctx
    public let exerciseID: UUID?
    public let intentRaw: String
    /// The in-progress session, excluded so the column never echoes a set
    /// logged in this same workout.
    public let currentSessionID: UUID?
    @State private var hint: PreviousMatchingIntentHit?

    public init(exerciseID: UUID?, intentRaw: String, currentSessionID: UUID? = nil) {
        self.exerciseID = exerciseID
        self.intentRaw = intentRaw
        self.currentSessionID = currentSessionID
    }

    public var body: some View {
        Group {
            if let hit = hint {
                Text(formatHint(hit))
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
            } else {
                Text("—")                                                           // UI-SPEC verbatim placeholder
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
            }
        }
        // Keyed on exerciseID so a mid-session swap re-queries.
        .task(id: exerciseID) {
            hint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: exerciseID,
                intentRaw: intentRaw,
                context: ctx,
                excludingSessionID: currentSessionID
            )
        }
    }

    /// Formats the matching-intent hit per UI-SPEC § Session logger line 545 + 580:
    /// "{prev weight} × {prev reps} @ {prev RPE} ({day-of-week ref})"
    /// e.g. "175 × 8 @ 8 (Mon)". RPE clause suppressed when the prior set
    /// didn't record one. Weight renders without decimal when integer.
    private func formatHint(_ hit: PreviousMatchingIntentHit) -> String {
        let day = hit.sessionStartedAt.formatted(.dateTime.weekday(.abbreviated))
        let rpeText: String
        if let rpe = hit.rpe {
            if rpe.truncatingRemainder(dividingBy: 1) == 0 {
                rpeText = "@ \(Int(rpe))"
            } else {
                rpeText = String(format: "@ %.1f", rpe)
            }
        } else {
            rpeText = ""
        }
        let w = hit.weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hit.weight))"
            : String(format: "%.1f", hit.weight)
        // UI-SPEC verbatim: "175 × 8 @ 8 (Mon)"
        return "\(w) × \(hit.reps) \(rpeText) (\(day))"
            .replacingOccurrences(of: "  ", with: " ")
    }
}

#if DEBUG
#Preview("placeholder (no hit)") {
    PreviousColumn(exerciseID: UUID(), intentRaw: "strength")
        .padding()
        .background(Color.bruPaper)
        .modelContainer(PreviewModelContainer.make())
}
#endif
