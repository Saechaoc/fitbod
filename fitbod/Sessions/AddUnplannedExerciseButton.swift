//
//  AddUnplannedExerciseButton.swift
//  fitbod
//
//  Wave-4 plan 04-02 — "+ Add Exercise" affordance at the bottom of the
//  session logger's list (SESS-06). Tapping opens an
//  `ExerciseLibraryView(onSelect:)` picker in a sheet; choosing an
//  exercise appends a brand-new `SessionExercise` row to the active
//  `Session.exercises` ONLY — the source `Routine.exercises` is never
//  touched (PITFALLS-doc #1 / RESEARCH § Anti-Patterns).
//
//  ## Defaulted prescription
//
//  Because there is no source `RoutineExercise` to snapshot from when
//  the user adds an unplanned exercise mid-session, prescription
//  defaults are computed:
//
//    - `intentRaw` = the exercise's mechanic-driven default (compound +
//      barbell → strength; otherwise hypertrophy). Phase 2 keeps this
//      simple — Phase 3's PrescriptionDefaults / progression strategy
//      will refine.
//    - `targetSets = 3`, `targetRepsLow = 8`, `targetRepsHigh = 12`.
//    - `prescribedRestSeconds = 180` (compound) or 90 (isolation).
//
//  Three planned `SetEntry` rows are seeded with the matching-intent
//  weight hint via `PreviousMatchingIntent.fetchTopWorkingSet` (same
//  path SessionFactory uses on session-start).
//
//  ## UI-SPEC verbatim
//
//  - Button label: "Add Exercise" (UI-SPEC § Session logger)
//  - Leading icon: `plus.circle` (UI-SPEC § Asset Contract)
//  - Sheet title: "Add Exercise"
//  - Toolbar cancel: "Cancel"
//

import SwiftUI
import SwiftData

public struct AddUnplannedExerciseButton: View {
    @Environment(\.modelContext) private var ctx
    @Bindable public var session: Session
    @State private var presentingPicker = false

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        Button {
            presentingPicker = true
        } label: {
            HStack(spacing: 4) {                                                // UI-SPEC xs
                Image(systemName: "plus.circle")                                // UI-SPEC § Asset Contract
                Text("Add Exercise")                                            // UI-SPEC verbatim
            }
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $presentingPicker) {
            NavigationStack {
                ExerciseLibraryView(onSelect: { exercise in
                    append(exercise: exercise)
                    presentingPicker = false
                })
                .navigationTitle("Add Exercise")                                // UI-SPEC verbatim
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { presentingPicker = false }           // UI-SPEC verbatim
                    }
                }
            }
        }
    }

    /// SESS-06 — append a fresh SessionExercise + 3 planned SetEntry rows.
    /// The source Routine is untouched.
    private func append(exercise: Exercise) {
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.orderIndex = (session.exercises ?? []).count
        se.intentRaw = defaultIntent(for: exercise).rawValue
        se.targetSets = 3
        se.targetRepsLow = 8
        se.targetRepsHigh = 12
        se.prescribedRestSeconds = exercise.mechanic == .compound ? 180 : 90
        ctx.insert(se)

        // Seed 3 planned sets with the matching-intent weight hint
        // (same path SessionFactory uses on session-start).
        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id,
            intentRaw: se.intentRaw,
            context: ctx
        )?.weight ?? 0
        for i in 0..<3 {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = hint
            entry.reps = 0
            entry.setTypeRaw = SetType.working.rawValue
            entry.isComplete = false
            entry.completedAt = .now
            ctx.insert(entry)
        }
        try? ctx.save()
    }

    /// CONTEXT.md Area 1 mechanic-driven default — compound + barbell
    /// gravitates to strength; everything else defaults to hypertrophy.
    /// Phase 3's PrescriptionDefaults will refine this; Phase 2 keeps
    /// the heuristic minimal so an add-unplanned exercise feels sensible
    /// out of the gate.
    private func defaultIntent(for exercise: Exercise) -> Intent {
        if exercise.mechanic == .compound && exercise.equipment == .barbell {
            return .strength
        }
        return .hypertrophy
    }
}

#Preview("add unplanned exercise button") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    ctx.insert(session)
    try? ctx.save()
    return AddUnplannedExerciseButton(session: session)
        .modelContainer(container)
}
