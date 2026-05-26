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
/// Reference: bru-screens/today.jsx lines 59-80.
public struct BlackSlabCTA: View {

    // MARK: - Properties

    let routine: Routine
    let dayIndex: Int       // 1-based, e.g. 1 of 4
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

                Text(String(format: "DAY %02d / %02d", dayIndex, totalDays))
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper.opacity(0.6))
            }

            // 6pt gap then hero routine name
            Spacer().frame(height: 6)

            BRUDisplay(routine.name, size: .hero, color: .bruPaper)

            // 12pt gap then meta strip
            Spacer().frame(height: 12)

            HStack(spacing: 0) {
                Text("\(exerciseCount) exercises")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper)

                Text("  ·  ")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.5))

                Text("\(setCount) sets")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper)

                Text("  ·  ")
                    .font(BRUFont.labelSmall)
                    .foregroundStyle(Color.bruPaper.opacity(0.5))

                Text("~\(estimatedMinutes) min")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruPaper)
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
}

// MARK: - Preview

#if DEBUG
private struct BlackSlabCTAPreviewContainer: View {
    let container: ModelContainer
    let routine: Routine

    var body: some View {
        BlackSlabCTA(routine: routine, dayIndex: 1, totalDays: 4, onStart: {})
            .modelContainer(container)
    }

    static func make() -> BlackSlabCTAPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Routine.self, RoutineExercise.self, Exercise.self,
            configurations: config
        )
        let routine = Routine()
        routine.name = "Push A"
        let specs: [(Int, String)] = [
            (3, "Bench Press"), (4, "Incline DB Press"),
            (4, "Cable Fly"), (5, "Tricep Pushdown"), (5, "OH Tricep Ext"),
        ]
        for (idx, spec) in specs.enumerated() {
            let ex = Exercise()
            ex.name = spec.1
            ex.canonicalName = spec.1
            let re = RoutineExercise()
            re.exercise = ex
            re.targetSets = spec.0
            re.targetRepsLow = 10
            re.targetRepsHigh = 12
            re.routine = routine
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
