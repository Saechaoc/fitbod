//
//  SupersetAssignmentSheet.swift
//  fitbod
//
//  Wave-3 plan 03-03 — the sheet presented by the long-press menu on a
//  `RoutineExerciseCard` when the user taps "Move to Superset…" or
//  "Make Superset". Lists every existing `SupersetGroup` in the current
//  routine + a "New Superset" accent action row (UI-SPEC accent surface
//  #9 / verbatim row label).
//
//  ## Row label format
//
//  UI-SPEC § Routine builder verbatim format:
//    "Superset A (Bench + Row)" / "Superset B (Squat + Curl)" / ...
//  The letter is `A + sortOrder` (A, B, C, …). The "(Bench + Row)"
//  suffix is the joined names of the RoutineExercise rows already
//  pointing at this group; empty groups render as just "Superset A".
//
//  ## Mutation surface
//
//  The sheet writes to `RoutineExerciseDraft.supersetGroupID` — the
//  in-memory builder draft, NOT the persisted `RoutineExercise` row.
//  The persisted write happens later in `RoutineDraft.save(into:)` on
//  the user's Save tap, so cancelling the builder leaves no side
//  effects in the SwiftData store.
//
//  ## SupersetGroup insertion
//
//  "New Superset" inserts a fresh `SupersetGroup` and immediately
//  saves the context so the row participates in `@Query` predicates
//  the next time the sheet is presented. The new group is assigned to
//  the current exercise draft; the user can then long-press a SECOND
//  exercise card and pick the now-listed "Superset A" entry to pair
//  them up.
//
//  ## Edge cases
//
//  - The sheet is gated on a saved routine in `RoutineBuilderView`
//    (the parent's `editing != nil` check). `SupersetGroup.routineID`
//    needs to point at a persisted Routine; presenting the sheet on
//    an unsaved draft would create orphan groups. The parent enforces
//    this contract — the sheet itself trusts that `routine` is
//    persisted.
//

import SwiftUI
import SwiftData

public struct SupersetAssignmentSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    public let routine: Routine
    public let exerciseDraft: RoutineExerciseDraft

    @Query private var groups: [SupersetGroup]

    public init(routine: Routine, exerciseDraft: RoutineExerciseDraft) {
        self.routine = routine
        self.exerciseDraft = exerciseDraft
        let routineID = routine.id
        self._groups = Query(
            filter: #Predicate<SupersetGroup> { $0.routineID == routineID },
            sort: \SupersetGroup.sortOrder
        )
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Button {
                        exerciseDraft.supersetGroupID = group.id
                        dismiss()
                    } label: {
                        Text(label(for: group))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    let newGroup = SupersetGroup(
                        routineID: routine.id,
                        kindRaw: SupersetKind.paired.rawValue,
                        sortOrder: groups.count
                    )
                    ctx.insert(newGroup)
                    try? ctx.save()
                    exerciseDraft.supersetGroupID = newGroup.id
                    dismiss()
                } label: {
                    Text("New Superset")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Add to Superset")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// UI-SPEC § Routine builder verbatim format:
    ///   "Superset A (Bench + Row)" / "Superset B (Squat + Curl)"
    /// Letter is derived from `sortOrder` (A = 0, B = 1, …). The
    /// "(Bench + Row)" suffix lists the names of every RoutineExercise
    /// pointing at this group; empty groups render as just
    /// "Superset A".
    private func label(for group: SupersetGroup) -> String {
        let letter = String(UnicodeScalar(UInt8(65 + group.sortOrder)))
        let routineExercises = (routine.exercises ?? [])
            .filter { $0.supersetGroupID == group.id }
        let names = routineExercises
            .compactMap { $0.exercise?.name }
            .joined(separator: " + ")
        if names.isEmpty {
            return "Superset \(letter)"
        }
        return "Superset \(letter) (\(names))"
    }
}
