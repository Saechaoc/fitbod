//
//  WarmupRampRows.swift
//  fitbod
//
//  Phase 3 plan 06 — renders the warm-up ramp block inside a
//  `SessionExerciseCard`, above the working set rows.
//
//  UI-SPEC § Warm-up ramp rows — all copy verbatim:
//    W{N} leading label / "{pct}% × {reps}" percentage hint in .caption .secondaryLabel
//    "Working sets" divider below last warm-up row (.caption .secondaryLabel, centered)
//    "Skip warm-ups" text button (.secondaryLabel — NOT accent)
//    "Warm up however you'd like." placeholder when working weight < 1.5× bar
//
//  Set count → ramp mapping:
//    count == 4 (barbell): orderIndex 0=40%×5, 1=60%×3, 2=75%×2, 3=90%×1
//    count == 2 (dumbbell/unilateral): orderIndex 0=60%×3, 1=90%×1
//    other counts: defensive linear fraction of working weight
//
//  plan 03-08 owns wiring this component into SessionExerciseCard.
//  This file does NOT modify SessionExerciseCard or SetRow.
//

import SwiftUI
import SwiftData

public struct WarmupRampRows: View {
    public let warmupSets: [SetEntry]
    public let onSkip: () -> Void
    /// The parent SessionExercise — used to read prescribedWeight for
    /// computing the percentage display from each warmup set's weight.
    public let sessionExercise: SessionExercise

    public init(
        warmupSets: [SetEntry],
        onSkip: @escaping () -> Void,
        sessionExercise: SessionExercise
    ) {
        self.warmupSets = warmupSets
        self.onSkip = onSkip
        self.sessionExercise = sessionExercise
    }

    // MARK: - Sorted warmups

    private var sortedWarmups: [SetEntry] {
        warmupSets.sorted { $0.orderIndex < $1.orderIndex }
    }

    public var body: some View {
        if warmupSets.isEmpty {
            // Placeholder when no ramp was generated (e.g. weight < 1.5× bar)
            Text("Warm up however you'd like.")                                  // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
        } else {
            VStack(spacing: 4) {
                // Warm-up set rows
                ForEach(sortedWarmups, id: \.id) { warmup in
                    warmupRow(warmup)
                }

                // "Skip warm-ups" text button — trailing, NOT accent per UI-SPEC
                Button("Skip warm-ups") {                                        // UI-SPEC verbatim
                    onSkip()
                }
                .font(.caption)
                .foregroundStyle(.secondary)                                     // NOT accent per UI-SPEC
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .accessibilityLabel("Skip all warm-up sets")
                .accessibilityHint("Marks warm-ups as done without logging them.") // UI-SPEC verbatim

                // "Working sets" divider between warmup and working rows
                workingSetsDivider()
            }
        }
    }

    // MARK: - Warmup row

    @ViewBuilder
    private func warmupRow(_ warmup: SetEntry) -> some View {
        let pct = percentageForSet(warmup)
        let repsHint = repsForOrderIndex(warmup.orderIndex, count: sortedWarmups.count)
        HStack(spacing: 8) {
            // Leading "W{N}" label — UI-SPEC verbatim
            Text("W\(warmup.orderIndex + 1)")                                    // UI-SPEC verbatim W{N}
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .leading)

            // Warmup chip — systemBlue per Phase 2 set-type chip color convention
            Text("warmup")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.systemBlue))
                .foregroundStyle(.white)
                .clipShape(Capsule())

            // Percentage hint in Previous-column area — .caption .secondaryLabel
            Text("\(pct)% × \(repsHint)")                                       // UI-SPEC verbatim "{pct}% × {reps}"
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Weight display
            Text(String(format: "%g", warmup.weight))
                .font(.body)

            // Reps display
            Text("× \(warmup.reps)")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityLabel(accessibilityLabel(for: warmup, pct: pct))
    }

    // MARK: - Working sets divider

    @ViewBuilder
    private func workingSetsDivider() -> some View {
        ZStack {
            Divider()
            Text("Working sets")                                                  // UI-SPEC verbatim
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Percentage helpers

    /// Returns the percentage label for a given warm-up set based on order + ramp count.
    private func percentageForSet(_ set: SetEntry) -> Int {
        let count = sortedWarmups.count
        switch count {
        case 4:
            // Barbell 4-set ramp: 40 / 60 / 75 / 90
            let pcts = [40, 60, 75, 90]
            let idx = min(set.orderIndex, pcts.count - 1)
            return pcts[idx]
        case 2:
            // Dumbbell 2-set ramp: 60 / 90
            let pcts = [60, 90]
            let idx = min(set.orderIndex, pcts.count - 1)
            return pcts[idx]
        default:
            // Defensive: linear fraction
            guard count > 1 else { return 50 }
            let step = 90 / max(count - 1, 1)
            return 40 + set.orderIndex * step
        }
    }

    /// Returns the rep count for a given orderIndex based on ramp shape.
    private func repsForOrderIndex(_ idx: Int, count: Int) -> Int {
        switch count {
        case 4:
            // Barbell: 5 / 3 / 2 / 1
            let reps = [5, 3, 2, 1]
            return reps[min(idx, reps.count - 1)]
        case 2:
            // Dumbbell: 3 / 1
            let reps = [3, 1]
            return reps[min(idx, reps.count - 1)]
        default:
            return max(1, 5 - idx)
        }
    }

    /// UI-SPEC a11y label for a warm-up row.
    private func accessibilityLabel(for warmup: SetEntry, pct: Int) -> String {
        "Warm-up set \(warmup.orderIndex + 1): \(String(format: "%g", warmup.weight)) kg × \(warmup.reps) reps at \(pct)% of working weight."
    }
}

// MARK: - Previews

#Preview("4-set barbell ramp") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 100
    ctx.insert(exercise)

    // Build 4 warmup SetEntry rows (40/60/75/90)
    let specs: [(pct: Double, reps: Int)] = [(0.40, 5), (0.60, 3), (0.75, 2), (0.90, 1)]
    let sets: [SetEntry] = specs.enumerated().map { idx, spec in
        let s = SetEntry()
        s.orderIndex = idx
        s.weight = (100.0 * spec.pct).rounded()
        s.reps = spec.reps
        s.isWarmup = true
        s.setTypeRaw = "warmup"
        s.sessionExercise = exercise
        ctx.insert(s)
        return s
    }
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: sets,
            onSkip: {},
            sessionExercise: exercise
        )
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
    .modelContainer(container)
}

#Preview("2-set dumbbell ramp") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 30
    ctx.insert(exercise)

    // Build 2 warmup rows (60%/90% dumbbell)
    let specs: [(pct: Double, reps: Int)] = [(0.60, 3), (0.90, 1)]
    let sets: [SetEntry] = specs.enumerated().map { idx, spec in
        let s = SetEntry()
        s.orderIndex = idx
        s.weight = (30.0 * spec.pct).rounded()
        s.reps = spec.reps
        s.isWarmup = true
        s.setTypeRaw = "warmup"
        s.sessionExercise = exercise
        ctx.insert(s)
        return s
    }
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: sets,
            onSkip: {},
            sessionExercise: exercise
        )
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
    .modelContainer(container)
}

#Preview("empty warmups — placeholder shown") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)

    let exercise = SessionExercise()
    exercise.prescribedWeight = 25
    ctx.insert(exercise)
    try? ctx.save()

    return ScrollView {
        WarmupRampRows(
            warmupSets: [],
            onSkip: {},
            sessionExercise: exercise
        )
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
    .modelContainer(container)
}
