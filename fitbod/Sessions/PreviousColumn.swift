//
//  PreviousColumn.swift
//  fitbod
//
//  Wave-4 plan 04-01 — the inline "Previous" column rendered between the
//  "Set N" label and the weight cell on every `SetRow`. Surfaces the most
//  recent matching-intent prior set for the exercise:
//
//    "175 × 8 @ 8 (Mon)"   — UI-SPEC verbatim format (§ Session logger)
//
//  When no matching-intent prior set exists, renders the UI-SPEC verbatim
//  placeholder "—".
//
//  The query is delegated to `PreviousMatchingIntent.fetchTopWorkingSet`
//  (the shared helper introduced in plan 01-01) — the same query that seeds
//  `SessionFactory.start`'s planned `SetEntry.weight` hint. Centralizing
//  the query keeps the two consumers semantically aligned (warmup
//  exclusion, isComplete filter, intent split for ROUTINE-08).
//
//  Performance discipline (RESEARCH § Anti-Patterns to Avoid):
//    - The query fires ONCE per row in `.task`, NOT on every body
//      invocation. The hit is cached in `@State` and read on subsequent
//      re-renders.
//    - `PreviousMatchingIntent.fetchTopWorkingSet` is bounded to 5 rows
//      (`fetchLimit = 5`) so the descriptor is cheap.
//

import SwiftUI
import SwiftData

public struct PreviousColumn: View {
    @Environment(\.modelContext) private var ctx
    public let exerciseID: UUID?
    public let intentRaw: String
    @State private var hint: PreviousMatchingIntentHit?

    public init(exerciseID: UUID?, intentRaw: String) {
        self.exerciseID = exerciseID
        self.intentRaw = intentRaw
    }

    public var body: some View {
        Group {
            if let hit = hint {
                Text(formatHint(hit))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")                                                       // UI-SPEC verbatim placeholder
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .task {
            hint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: exerciseID,
                intentRaw: intentRaw,
                context: ctx
            )
        }
    }

    /// Formats the matching-intent hit per UI-SPEC § Session logger:
    /// "{prev weight} × {prev reps} @ {prev RPE} ({day-of-week ref})"
    /// e.g. "175 × 8 @ 8 (Mon)". RPE clause is suppressed when the prior
    /// set didn't record one. Weight renders without decimal when the
    /// value is an integer (175 vs 177.5).
    private func formatHint(_ hit: PreviousMatchingIntentHit) -> String {
        let day = hit.sessionStartedAt.formatted(.dateTime.weekday(.abbreviated))
        let rpeText: String
        if let rpe = hit.rpe {
            // Render integer RPE without ".0"; render decimal RPE with one digit.
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

#Preview("placeholder (no hit)") {
    PreviousColumn(exerciseID: UUID(), intentRaw: "strength")
        .padding()
        .modelContainer(PreviewModelContainer.make())
}
