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
/// The number column scales with its type, so "01" stays on one line. At
/// accessibility sizes the chip moves under the name and sub-line, since
/// beside them it broke "COMPOUND" over two lines.
///
/// Reference: bru-screens/today.jsx lines 92-108.
public struct LiftListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The 32pt number column, scaled like its 22pt type.
    @ScaledMetric(relativeTo: .title2) private var numberWidth: CGFloat = 32

    // MARK: - Properties

    let index: Int                  // 1-based display index
    let routineExercise: SessionExerciseTemplate
    let isFirstCompound: Bool       // true → COMPOUND chip (signal); false → WORK chip (ink)

    // MARK: - Computed

    private var exerciseName: String {
        routineExercise.exercise?.name ?? "Exercise"
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
                // Leading index — 32pt wide at default text, displayMedium 22pt, zero-padded
                Text(String(format: "%02d", index))
                    .font(.bru(.grotesk, size: 22))
                    .foregroundStyle(Color.bruInk)
                    .fixedSize()
                    .frame(width: numberWidth, alignment: .leading)

                // Middle — name + sub-line, then the chip at accessibility sizes
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

                    if dynamicTypeSize.isAccessibilitySize {
                        chip
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Trailing — the chip beside the name at standard sizes
                if !dynamicTypeSize.isAccessibilitySize {
                    chip
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 16)

            // 1pt bruHair row separator
            BRUDivider(.hair)
        }
        .background(Color.bruPaper)
    }

    /// COMPOUND (signal) or WORK (ink), never broken over two lines.
    private var chip: some View {
        BRUChip(
            isFirstCompound ? "Compound" : "Work",
            color: isFirstCompound ? .bruSignal : .bruInk
        )
        .fixedSize()
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
            LiftListRow(index: 1, routineExercise: benchRE, isFirstCompound: true)
            LiftListRow(index: 2, routineExercise: flyRE, isFirstCompound: false)
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
        benchRE.generateWarmups = true
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
