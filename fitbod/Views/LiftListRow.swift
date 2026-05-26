// LiftListRow.swift
// fitbod — Phase 2.1 Plan 04
//
// A single row in the Lift list — 3-column layout with zero-padded index,
// exercise name + sub-line, and a COMPOUND/WORK chip.
// Reference: bru-screens/today.jsx lines 92-108
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - LiftListRow

/// A single lift-list row — zero-padded index, name + sub-line, trailing chip.
///
/// Layout (grid: 32pt | flex | auto):
/// ```
/// ┌──────┬────────────────────────────┬────────────┐
/// │  01  │  Bench Press               │  COMPOUND  │
/// │      │  2 WARM-UP · 3 WORK · ...  │            │
/// └──────┴────────────────────────────┴────────────┘
/// ──────────────────────────────────────────────────  1pt bruHair
/// ```
///
/// Reference: bru-screens/today.jsx lines 92-108.
public struct LiftListRow: View {

    // MARK: - Properties

    let index: Int                  // 1-based display index
    let routineExercise: RoutineExercise
    let isFirstCompound: Bool       // true → COMPOUND chip (signal); false → WORK chip (ink)

    // MARK: - Computed

    private var exerciseName: String {
        routineExercise.exercise?.canonicalName ?? routineExercise.exercise?.name ?? "Exercise"
    }

    private var setSubLine: String {
        let warmups = routineExercise.generateWarmups ? 2 : 0  // approximate warm-up count
        let sets = routineExercise.targetSets
        let lo = routineExercise.targetRepsLow
        let hi = routineExercise.targetRepsHigh

        if warmups > 0 {
            return "\(warmups) warm-up · \(sets) work"
        } else {
            return "\(sets) × \(lo)-\(hi)"
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Leading index — 32pt wide, displayMedium 22pt, zero-padded
                Text(String(format: "%02d", index))
                    .font(.custom("SpaceGrotesk-Bold", size: 22))
                    .foregroundStyle(Color.bruInk)
                    .frame(width: 32, alignment: .leading)

                // Middle — name + sub-line
                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseName)
                        .font(BRUFont.bodyEmphasis)
                        .tracking(-0.2)
                        .foregroundStyle(Color.bruInk)

                    Text(setSubLine)
                        .font(BRUFont.labelSmall)
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Trailing — COMPOUND (signal) or WORK (ink)
                BRUChip(
                    isFirstCompound ? "Compound" : "Work",
                    color: isFirstCompound ? .bruSignal : .bruInk
                )
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 16)

            // 1pt bruHair row separator
            BRUDivider(.hair)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
private struct LiftListRowPreviewContainer: View {
    let container: ModelContainer
    let benchRE: RoutineExercise
    let flyRE: RoutineExercise

    var body: some View {
        VStack(spacing: 0) {
            LiftListRow(index: 1, routineExercise: benchRE, isFirstCompound: true)
            LiftListRow(index: 2, routineExercise: flyRE, isFirstCompound: false)
        }
        .modelContainer(container)
        .background(Color.bruPaper)
    }

    static func make() -> LiftListRowPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: RoutineExercise.self, Exercise.self,
            configurations: config
        )
        let bench = Exercise()
        bench.name = "Bench Press"
        bench.mechanicRaw = "compound"
        let benchRE = RoutineExercise()
        benchRE.exercise = bench
        benchRE.targetSets = 3
        benchRE.targetRepsLow = 5
        benchRE.targetRepsHigh = 5
        benchRE.generateWarmups = true
        benchRE.orderIndex = 0
        container.mainContext.insert(bench)
        container.mainContext.insert(benchRE)

        let fly = Exercise()
        fly.name = "Cable Fly"
        fly.mechanicRaw = "isolation"
        let flyRE = RoutineExercise()
        flyRE.exercise = fly
        flyRE.targetSets = 3
        flyRE.targetRepsLow = 12
        flyRE.targetRepsHigh = 15
        flyRE.orderIndex = 1
        container.mainContext.insert(fly)
        container.mainContext.insert(flyRE)
        return LiftListRowPreviewContainer(container: container, benchRE: benchRE, flyRE: flyRE)
    }
}

#Preview("LiftListRow variants") {
    LiftListRowPreviewContainer.make()
}
#endif
