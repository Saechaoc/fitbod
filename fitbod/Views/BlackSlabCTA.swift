// BlackSlabCTA.swift
// fitbod — Phase 2.1 Plan 04
//
// "{TODAY or NEXT UP · n OF m} · {routine} · Start workout ▸" full-bleed ink slab CTA.
// Reference: bru-screens/today.jsx lines 59-80
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - BlackSlabCTA

/// Full-bleed bruSlab slab showing the next scheduled workout with a CTA;
/// dark in both appearances (FT-14), text in bruOnSlab.
///
/// Layout (top to bottom, 18pt v / 16pt h padding):
/// ```
/// ┌───────────────────────────────────────────────┐  ← bruSlab (dark in both appearances)
/// │  NEXT UP · 1 OF 4                             │  10pt caps 0.6 opacity
/// │                                               │  6pt gap
/// │  Push A                                       │  56pt hero bruOnSlab
/// │                                               │  12pt gap
/// │  5 EXERCISES  ·  21 SETS  ·  ~52 MIN          │  10pt caps 0.5 opacity
/// │  DELOAD WEEK · LIGHTER SETS                   │  in a deload week only
/// │                                               │  16pt gap
/// │  [       START WORKOUT ▸        ]             │  BRUPillButton signal
/// └───────────────────────────────────────────────┘
/// ```
///
/// The label is `heroLabel(mode:position:slotCount:)` in a block: TODAY on a
/// fixed-weekly block, the session's place in the cycle on a rotation. With
/// no block it is `heroLabel(routine:)`, which names the routine. The
/// set count is the working sets the phase yields, the count the factory
/// plans (`PeriodizationEngine.workingSetCount`), and a deload week says
/// so under the meta line.
///
/// When the meta line does not fit on one line, as at accessibility sizes
/// and at xxLarge and up on the 390pt phone, its parts stack, one per line,
/// since a squeezed line would break "1" from "EXERCISE" or "EXERCISES"
/// mid-word.
///
/// Reference: bru-screens/today.jsx lines 59-80.
public struct BlackSlabCTA: View {

    // MARK: - Properties

    let routine: SessionTemplate
    /// The top label, from `heroLabel(mode:position:slotCount:)`.
    let label: String
    /// The block's current phase; a deload cuts the set count and adds the caption.
    let phase: BlockPhase?
    let onStart: @MainActor () -> Void

    // MARK: - Label

    /// TODAY on a fixed-weekly block; on a rotation the session's place in
    /// the cycle, "NEXT UP · 2 OF 3" for `position` 1 of 3 slots.
    static func heroLabel(mode: SchedulingMode, position: Int, slotCount: Int) -> String {
        mode == .fixedWeekly ? "TODAY" : "NEXT UP · \(position + 1) OF \(slotCount)"
    }

    /// With no block: "NEXT UP · PUSH PULL LEGS", naming the routine the
    /// suggested session comes from, or "NEXT UP" alone for a session that
    /// sits in no routine.
    static func heroLabel(routine: Split?) -> String {
        routine.map { "NEXT UP · \($0.name)" } ?? "NEXT UP"
    }

    // MARK: - Computed

    private var exerciseCount: Int {
        (routine.exercises ?? []).count
    }

    /// The working sets the phase yields, summed: what the factory will plan.
    private var setCount: Int {
        (routine.exercises ?? []).reduce(0) {
            $0 + PeriodizationEngine.workingSetCount(targetSets: $1.targetSets, phase: phase)
        }
    }

    /// Rough ~duration estimate — 3 min avg per set + 2 min overhead
    private var estimatedMinutes: Int {
        max(1, setCount * 3 + 2)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: TODAY, or the session's place in the cycle
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSlab.opacity(0.6))

            // 6pt gap then hero routine name
            Spacer().frame(height: 6)

            BRUDisplay(routine.name, size: .hero, color: .bruOnSlab)

            // 12pt gap then meta strip
            Spacer().frame(height: 12)

            // One line while it fits; otherwise the parts stack, each whole.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    metaPart(BRUCountLabel.text(exerciseCount, "exercise"))
                    metaSeparator
                    metaPart(BRUCountLabel.text(setCount, "set"))
                    metaSeparator
                    metaPart("~\(estimatedMinutes) min")
                }
                VStack(alignment: .leading, spacing: 4) {
                    metaPart(BRUCountLabel.text(exerciseCount, "exercise"))
                    metaPart(BRUCountLabel.text(setCount, "set"))
                    metaPart("~\(estimatedMinutes) min")
                }
            }

            // A deload week says why the sets are fewer.
            if phase?.kind == .deload {
                Spacer().frame(height: 6)
                Text("Deload week · lighter sets")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruOnSlab.opacity(0.6))
            }

            // 16pt gap then CTA
            Spacer().frame(height: 16)

            BRUPillButton("Start workout ▸", action: onStart)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.bruSlab)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One part of the meta line, such as "1 EXERCISE".
    private func metaPart(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruOnSlab)
    }

    /// The dot between two meta parts on one line; stacked parts need none.
    private var metaSeparator: some View {
        Text("  ·  ")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruOnSlab.opacity(0.5))
    }
}

// MARK: - Preview

#if DEBUG
private struct BlackSlabCTAPreviewContainer: View {
    let container: ModelContainer
    let routine: SessionTemplate

    var body: some View {
        BlackSlabCTA(routine: routine, label: "NEXT UP · 1 OF 3", phase: nil, onStart: {})
            .modelContainer(container)
    }

    static func make() -> BlackSlabCTAPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: SessionTemplate.self, SessionExerciseTemplate.self, Exercise.self,
            configurations: config
        )
        let routine = SessionTemplate()
        routine.name = "Push A"
        let specs: [(Int, String)] = [
            (3, "Bench Press"), (4, "Incline DB Press"),
            (4, "Cable Fly"), (5, "Tricep Pushdown"), (5, "OH Tricep Ext"),
        ]
        for (idx, spec) in specs.enumerated() {
            let ex = Exercise()
            ex.name = spec.1
            ex.canonicalName = spec.1
            let re = SessionExerciseTemplate()
            re.exercise = ex
            re.targetSets = spec.0
            re.targetRepsLow = 10
            re.targetRepsHigh = 12
            re.sessionTemplate = routine
            re.orderIndex = idx
            container.mainContext.insert(ex)
            container.mainContext.insert(re)
        }
        container.mainContext.insert(routine)
        return BlackSlabCTAPreviewContainer(container: container, routine: routine)
    }
}

#Preview("BlackSlabCTA") {
    BlackSlabCTAPreviewContainer.make()
}
#endif
