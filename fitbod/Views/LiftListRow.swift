// LiftListRow.swift
// fitbod — Phase 2.1 Plan 04
//
// A single row in the Exercises list: zero-padded index, exercise name and
// the working sets × reps the phase yields.
// Reference: bru-screens/today.jsx lines 92-108
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - LiftListRow

/// A single exercises row: zero-padded index, name and the sets sub-line.
///
/// Layout (grid: 32pt | flex):
/// ```
/// ┌──────┬────────────────────────────┐
/// │  01  │  Bench Press               │
/// │      │  3 × 5-5                   │
/// └──────┴────────────────────────────┘
/// ──────────────────────────────────────  1pt bruHair
/// ```
///
/// The sub-line counts the working sets the phase yields
/// (`PeriodizationEngine.workingSetCount`), the sets the hero sums and the
/// factory plans. The number column scales with its type, so "01" stays on
/// one line.
///
/// Reference: bru-screens/today.jsx lines 92-108.
public struct LiftListRow: View {
    /// The 32pt number column, scaled like its 22pt type.
    @ScaledMetric(relativeTo: .title2) private var numberWidth: CGFloat = 32

    // MARK: - Properties

    let index: Int                  // 1-based display index
    let routineExercise: SessionExerciseTemplate
    /// The block's current phase; a deload cuts the working sets.
    let phase: BlockPhase?

    // MARK: - Computed

    private var exerciseName: String {
        routineExercise.exercise?.name ?? "Exercise"
    }

    private var setSubLine: String {
        let sets = PeriodizationEngine.workingSetCount(targetSets: routineExercise.targetSets, phase: phase)
        // A timed exercise has no rep target.
        if routineExercise.exercise?.tracking.isTimed == true { return BRUCountLabel.text(sets, "set") }
        return "\(sets) × \(routineExercise.targetRepsLow)-\(routineExercise.targetRepsHigh)"
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Leading index — 32pt wide at default text, displayMedium 22pt, zero-padded
                Text(String(format: "%02d", index))
                    .font(.bru(.grotesk, size: 22))
                    .foregroundStyle(Color.bruInk)
                    .fixedSize()
                    .frame(width: numberWidth, alignment: .leading)

                // Middle: name + sub-line
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
    let benchRE: SessionExerciseTemplate
    let flyRE: SessionExerciseTemplate

    var body: some View {
        VStack(spacing: 0) {
            LiftListRow(index: 1, routineExercise: benchRE, phase: nil)
            LiftListRow(index: 2, routineExercise: flyRE, phase: nil)
        }
        .modelContainer(container)
        .background(Color.bruPaper)
    }

    static func make() -> LiftListRowPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: SessionExerciseTemplate.self, Exercise.self,
            configurations: config
        )
        let bench = Exercise()
        bench.name = "Bench Press"
        bench.mechanicRaw = "compound"
        let benchRE = SessionExerciseTemplate()
        benchRE.exercise = bench
        benchRE.targetSets = 3
        benchRE.targetRepsLow = 5
        benchRE.targetRepsHigh = 5
        benchRE.orderIndex = 0
        container.mainContext.insert(bench)
        container.mainContext.insert(benchRE)

        let fly = Exercise()
        fly.name = "Cable Fly"
        fly.mechanicRaw = "isolation"
        let flyRE = SessionExerciseTemplate()
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
