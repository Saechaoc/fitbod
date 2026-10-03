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
                // The column is 80pt wide. Show the longest form that fits
                // without truncation: full "175 × 8 @ 8 (Mon)", then without
                // the day, then the bare "175×8". The full string stays the
                // accessibility label.
                ViewThatFits(in: .horizontal) {
                    hintText(formatHint(hit))
                    hintText(formatHint(hit, includeDay: false))
                    hintText(compactHint(hit))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Previous: \(formatHint(hit))")
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
    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.bodyDefault)
            .monospacedDigit()
            .foregroundStyle(Color.bruMuted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// "175×8" — the narrowest form.
    private func compactHint(_ hit: PreviousMatchingIntentHit) -> String {
        "\(formatWeight(hit.weight))×\(hit.reps)"
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    private func formatHint(_ hit: PreviousMatchingIntentHit, includeDay: Bool = true) -> String {
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
        let w = formatWeight(hit.weight)
        // UI-SPEC verbatim: "175 × 8 @ 8 (Mon)"
        let dayText = includeDay ? " (\(day))" : ""
        return "\(w) × \(hit.reps) \(rpeText)\(dayText)"
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
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
