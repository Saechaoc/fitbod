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
// Format:
//   Populated:   "175×8 @8", or "175×8" when the RPE does not fit the
//                80pt column — the compact set notation the exercise
//                history uses. BRUFont.bodyDefault mono bruMuted.
//   Empty:       "—"   — BRUFont.bodyDefault mono bruMuted
//   VoiceOver:   "Previous: 175 × 8 @ 8 (Mon)" — the UI-SPEC long form.
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
                // The column is 80pt wide. Every row uses the same compact
                // notation, "175×8 @8", and drops only the RPE when even
                // that does not fit. (Mixing the spaced long form on one
                // exercise with the compact form on the next looked
                // inconsistent.) The full string stays the accessibility
                // label.
                ViewThatFits(in: .horizontal) {
                    hintText(compactHint(hit, includeRPE: true))
                    hintText(compactHint(hit, includeRPE: false))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Previous: \(formatHint(hit))")
            } else {
                Text("—")                                                           // UI-SPEC verbatim placeholder
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
                    // VoiceOver reads a bare dash as "em dash".
                    .accessibilityLabel("No previous set")
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

    /// One muted, single-line hint that never truncates, so ViewThatFits
    /// can tell whether it fits.
    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.bodyDefault)
            .monospacedDigit()
            .foregroundStyle(Color.bruMuted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// "175×8 @8", or "175×8" without the RPE (also when none was logged).
    private func compactHint(_ hit: PreviousMatchingIntentHit, includeRPE: Bool) -> String {
        let set = "\(formatNumber(hit.weight))×\(hit.reps)"
        guard includeRPE, let rpe = hit.rpe else { return set }
        return "\(set) @\(formatNumber(rpe))"
    }

    /// Whole numbers drop the decimal: 100 → "100", 102.5 → "102.5".
    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    /// UI-SPEC long form for VoiceOver: "175 × 8 @ 8 (Mon)". The RPE clause
    /// is left out when the prior set didn't record one.
    private func formatHint(_ hit: PreviousMatchingIntentHit) -> String {
        let day = hit.sessionStartedAt.formatted(.dateTime.weekday(.abbreviated))
        let rpeText = hit.rpe.map { " @ \(formatNumber($0))" } ?? ""
        return "\(formatNumber(hit.weight)) × \(hit.reps)\(rpeText) (\(day))"
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
