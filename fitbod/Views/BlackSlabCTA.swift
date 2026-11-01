// BlackSlabCTA.swift
// fitbod — Phase 2.1 Plan 04
//
// "NEXT · {routine} · Start workout ▸" full-bleed ink slab CTA.
// Reference: bru-screens/today.jsx lines 59-80
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - BlackSlabCTA

/// Full-bleed bruInk slab showing the next scheduled workout with a CTA.
///
/// Layout (top to bottom, 18pt v / 16pt h padding):
/// ```
/// ┌──────────────────────────────────────────────┐  ← bruInk
/// │  NEXT                          DAY 01 / 04   │  10pt caps 0.6 opacity
/// │                                               │  6pt gap
/// │  Push A                                       │  56pt hero bruPaper
/// │                                               │  12pt gap
/// │  5 EXERCISES  ·  21 SETS  ·  ~52 MIN          │  10pt caps 0.5 opacity
/// │                                               │  16pt gap
/// │  [       START WORKOUT ▸        ]             │  BRUPillButton signal
/// └──────────────────────────────────────────────┘
/// ```
///
/// When the meta line does not fit on one line, as at accessibility sizes
/// and at xxLarge and up on the 390pt phone, its parts stack, one per line,
/// since a squeezed line would break "1" from "EXERCISE" or "EXERCISES"
/// mid-word. With no day, past the block's plan, the top row shows NEXT
/// alone (tradeoffs.md "A block past its plan").
///
/// Reference: bru-screens/today.jsx lines 59-80.
public struct BlackSlabCTA: View {

    // MARK: - Properties

    let routine: SessionTemplate
    let dayIndex: Int?      // 1-based, e.g. 1 of 4; nil shows no day
    let totalDays: Int
    let onStart: @MainActor () -> Void

    // MARK: - Computed

    private var exerciseCount: Int {
        (routine.exercises ?? []).count
    }

    private var setCount: Int {
        (routine.exercises ?? []).reduce(0) { $0 + $1.targetSets }
    }

    /// Rough ~duration estimate — 3 min avg per set + 2 min overhead
    private var estimatedMinutes: Int {
        max(1, setCount * 3 + 2)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: NEXT (leading) + DAY NN / MM (trailing)
            HStack {
                Text("NEXT")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))

                Spacer()

                if let dayIndex {
                    Text(String(format: "DAY %02d / %02d", dayIndex, totalDays))
                        .font(BRUFont.labelSmall)
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruPaper.opacity(0.6))
                }
            }

            // 6pt gap then hero routine name
            Spacer().frame(height: 6)

            BRUDisplay(routine.name, size: .hero, color: .bruPaper)

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

            // 16pt gap then CTA
            Spacer().frame(height: 16)

            BRUPillButton("Start workout ▸", action: onStart)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.bruInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One part of the meta line, such as "1 EXERCISE".
    private func metaPart(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruPaper)
    }

    /// The dot between two meta parts on one line; stacked parts need none.
    private var metaSeparator: some View {
        Text("  ·  ")
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruPaper.opacity(0.5))
    }
}

// MARK: - Preview

#if DEBUG
private struct BlackSlabCTAPreviewContainer: View {
    let container: ModelContainer
    let routine: SessionTemplate

    var body: some View {
        BlackSlabCTA(routine: routine, dayIndex: 1, totalDays: 4, onStart: {})
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
