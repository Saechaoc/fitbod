//
//  SwapExerciseSheet.swift
//  fitbod
//
//  Wave-4 plan 04-02 — mid-session swap (SESS-05). Long-pressing the
//  header on a `SessionExerciseCard` surfaces "Swap Exercise…" in a
//  contextMenu. Tapping it presents this sheet, which embeds
//  Phase 1's `ExerciseLibraryView(onSelect:)` picker. Choosing a row
//  mutates `SessionExercise.exercise` on the active session ONLY —
//  the source `RoutineExercise.exercise` is never touched
//  (PITFALLS-doc #1 / RESEARCH § Anti-Patterns).
//
//  ## Pending-set re-seed behaviour
//
//  Swapping mid-session re-seeds the still-pending (un-committed) sets
//  using `PreviousMatchingIntent.fetchTopWorkingSet` against the NEW
//  exercise + the snapshotted intent. Already-committed sets stay
//  immutable (logged history is never rewritten). Pending sets have
//  their `weight` overwritten with the new hint (or 0 if none),
//  `reps` reset to 0, and `rpe` cleared so the user starts fresh on
//  the swapped exercise.
//
//  ## Phase 3.1 (PIVOT-02 / PIVOT-05) reshape
//
//  Intent is a SESSION-level field after Plan 02. The swap reads
//  `sessionExercise.session?.intentRaw` (with a `.strength` fallback
//  matching FOUND-03's default-string pattern when the session somehow
//  detaches). The previous `sessionExercise.intentRaw` write at session
//  init is gone — every SessionExercise inherits intent from its parent
//  Session.
//
//  ## Footer copy (UI-SPEC verbatim)
//
//  "This swap applies to this session only. The routine template will
//  not change." — anchored verbatim from UI-SPEC § Session logger
//  "Swap-exercise footer note".
//

import SwiftUI
import SwiftData

public struct SwapExerciseSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Bindable public var sessionExercise: SessionExercise

    public init(sessionExercise: SessionExercise) {
        self.sessionExercise = sessionExercise
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ExerciseLibraryView(onSelect: { exercise in
                    // SESS-05 — mutate SessionExercise.exercise ONLY.
                    // The source RoutineExercise.exercise is untouched.
                    sessionExercise.exercise = exercise

                    // Re-seed pending sets with the new exercise's
                    // matching-intent hint. Committed sets are immutable
                    // (PITFALLS-doc #1 — historical data is never
                    // rewritten). PIVOT-02 / PIVOT-05: intent is read
                    // from the parent Session (fallback to .strength if
                    // the session relationship is somehow nil — matches
                    // FOUND-03 default-string pattern).
                    let hint = PreviousMatchingIntent.fetchTopWorkingSet(
                        exerciseID: exercise.id,
                        intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
                        context: ctx
                    )?.weight ?? 0
                    let pendingSets = (sessionExercise.sets ?? [])
                        .filter { !$0.isComplete }
                    for set in pendingSets {
                        set.weight = hint
                        set.reps = 0
                        set.rpe = nil
                    }
                    try? ctx.save()
                    dismiss()
                })
                Text("This swap applies to this session only. The routine template will not change.")   // UI-SPEC verbatim
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(16)
            }
            .navigationTitle("Swap Exercise")                                  // UI-SPEC verbatim
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }                             // UI-SPEC verbatim
                }
            }
        }
    }
}

#Preview("swap exercise sheet") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    // PIVOT-02 / PIVOT-05 — intent lives on the parent Session, not the
    // SessionExercise. Wire a session into the preview so the swap-sheet
    // exercises the real session-level intent read path.
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    session.intentRaw = Intent.strength.rawValue
    ctx.insert(session)
    let se = SessionExercise()
    se.session = session
    se.exercise = ex
    ctx.insert(se)
    try? ctx.save()
    return SwapExerciseSheet(sessionExercise: se)
        .modelContainer(container)
}
