// LiftListSection.swift
// fitbod — Phase 2.1 Plan 04
//
// BRUSectionHead("Lift list", right: "Tap to reorder") + LazyVStack of LiftListRow.
// Reference: bru-screens/today.jsx lines 83-110
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - LiftListSection

/// Section head + list of LiftListRow for the today-tab's "Up next" exercise list.
///
/// When routine is nil or has no exercises, renders a minimal "Add an exercise
/// to begin." placeholder (NOT the full empty-state surface — that lives at TodayView).
public struct LiftListSection: View {

    // MARK: - Properties

    let routine: Routine?

    // MARK: - Computed

    private var sortedExercises: [RoutineExercise] {
        (routine?.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Index of the first compound exercise (for COMPOUND chip rendering)
    private var firstCompoundIndex: Int? {
        sortedExercises.firstIndex { re in
            re.exercise?.mechanic == .compound
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Lift list", right: "Tap to reorder")

            if sortedExercises.isEmpty {
                // Minimal placeholder — not the full empty-state (that's TodayView's job)
                Text("Add an exercise to begin.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { offset, re in
                        LiftListRow(
                            index: offset + 1,
                            routineExercise: re,
                            isFirstCompound: offset == firstCompoundIndex
                        )
                    }
                }
            }
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
private struct LiftListSectionPreviewContainer: View {
    let container: ModelContainer
    let routine: Routine

    var body: some View {
        LiftListSection(routine: routine)
            .modelContainer(container)
            .background(Color.bruPaper)
    }

    static func make() -> LiftListSectionPreviewContainer {
        let config = try! ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Routine.self, RoutineExercise.self, Exercise.self,
            configurations: config
        )
        let fixture: [(String, String, Int, Int, Int)] = [
            ("Bench Press", "compound", 3, 5, 5),
            ("Incline DB Press", "compound", 4, 8, 10),
            ("Cable Fly", "isolation", 3, 12, 15),
            ("Tricep Pushdown", "isolation", 4, 12, 15),
            ("OH Tricep Ext", "isolation", 3, 15, 20),
        ]
        let routine = Routine()
        routine.name = "Push A"
        container.mainContext.insert(routine)
        for (idx, spec) in fixture.enumerated() {
            let ex = Exercise()
            ex.name = spec.0
            ex.canonicalName = spec.0
            ex.mechanicRaw = spec.1
            let re = RoutineExercise()
            re.exercise = ex
            re.targetSets = spec.2
            re.targetRepsLow = spec.3
            re.targetRepsHigh = spec.4
            re.routine = routine
            re.orderIndex = idx
            container.mainContext.insert(ex)
            container.mainContext.insert(re)
        }
        return LiftListSectionPreviewContainer(container: container, routine: routine)
    }
}

#Preview("LiftListSection — 5 exercises (today.jsx fixture)") {
    LiftListSectionPreviewContainer.make()
}

#Preview("LiftListSection — empty (nil routine)") {
    LiftListSection(routine: nil)
        .background(Color.bruPaper)
}
#endif
