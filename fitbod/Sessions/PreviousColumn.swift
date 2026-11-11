// PreviousColumn.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 42).
// UI-SPEC v2 § Session logger line 545 + 580.
//
// The inline LAST TIME column rendered between the "Set N" label and the
// weight cell on every SetRow. Surfaces the most recent matching-intent prior
// set for the exercise; the card's column header explains that (FT-07).
//
// Format:
//   Populated:   "175×8 @8", or "175×8" when the RPE does not fit the
//                80pt column — the compact set notation the exercise
//                history uses. BRUFont.bodyDefault mono bruMuted.
//   Empty:       "none yet"   — BRUFont.bodyDefault mono bruMuted
//   VoiceOver:   "Last time, same intent: 175 × 8 @ 8 (Mon)" — the
//                UI-SPEC long form.
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
    /// Labels a timed set's distance; weights show without a unit.
    public let unit: WeightUnit
    /// The machine this log is on (RM-066), nil for none: the column shows
    /// that machine's last set, or another machine's for reference.
    public let machineID: UUID?
    @State private var hint: PreviousMatchingIntentHit?

    public init(
        exerciseID: UUID?, intentRaw: String, currentSessionID: UUID? = nil,
        unit: WeightUnit = .default, machineID: UUID? = nil
    ) {
        self.exerciseID = exerciseID
        self.intentRaw = intentRaw
        self.currentSessionID = currentSessionID
        self.unit = unit
        self.machineID = machineID
    }

    /// What the column asks about: a swap or a machine change asks again.
    private struct Query: Equatable {
        let exerciseID: UUID?
        let machineID: UUID?
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
                .accessibilityLabel(
                    hit.onOtherMachine
                        ? "Last time, on another machine: \(formatHint(hit))"
                        : "Last time, same intent: \(formatHint(hit))"
                )
            } else {
                // Words, not a dash: a dash read as missing data (FT-07).
                Text("none yet")
                    .font(BRUFont.bodyDefault)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityLabel("No earlier set at this intent")
            }
        }
        .task(id: Query(exerciseID: exerciseID, machineID: machineID)) {
            hint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: exerciseID,
                intentRaw: intentRaw,
                context: ctx,
                excludingSessionID: currentSessionID,
                machineID: machineID
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

    /// The set by its own values, so a timed set reads as its time.
    private func result(_ hit: PreviousMatchingIntentHit, compact: Bool) -> String {
        SetText.result(
            weight: hit.weight, reps: hit.reps,
            durationSeconds: hit.durationSeconds, distanceMeters: hit.distanceMeters, level: hit.level,
            unit: unit, compact: compact
        )
    }

    /// "175×8 @8", or "175×8" without the RPE (also when none was logged).
    /// A timed set reads "20:00 L8".
    private func compactHint(_ hit: PreviousMatchingIntentHit, includeRPE: Bool) -> String {
        let set = result(hit, compact: true)
        guard includeRPE, let rpe = hit.rpe else { return set }
        return "\(set) @\(NumberText.weight(rpe))"
    }

    /// UI-SPEC long form for VoiceOver: "175 × 8 @ 8 (Mon)". The RPE clause
    /// is left out when the prior set didn't record one.
    private func formatHint(_ hit: PreviousMatchingIntentHit) -> String {
        let day = hit.sessionStartedAt.formatted(.dateTime.weekday(.abbreviated))
        let rpeText = hit.rpe.map { " @ \(NumberText.weight($0))" } ?? ""
        let set = hit.reps == 0 && hit.durationSeconds != nil
            ? result(hit, compact: false)
            : "\(NumberText.weight(hit.weight)) × \(hit.reps)"
        return "\(set)\(rpeText) (\(day))"
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
