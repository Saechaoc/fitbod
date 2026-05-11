//
//  SessionLoggerView.swift
//  fitbod
//
//  Wave-4 plan 04-01 — the user-facing centerpiece of Phase 2. The active
//  workout-logging surface bound to a `@Bindable Session`. Mounted via
//  `NavigationStack` push from:
//
//    - The Routines tab — `RoutinesListView.handleStartTap` pushes
//      `SessionRoute.logger(session)` after `SessionFactory.start` succeeds.
//    - The Today tab — `ResumeWorkoutBanner.onResume` pushes the same
//      route for an existing active session.
//
//  ## Layout (UI-SPEC § Session logger)
//
//      ┌────────────────────────────────────────────────────────────┐
//      │  RestTimerOverlay (mounted unconditionally; EmptyView when │
//      │  the engine isn't running)                                 │
//      ├────────────────────────────────────────────────────────────┤
//      │  [clock 32:14] [3 of 6] [pencil Notes]   ← header chips    │
//      ├────────────────────────────────────────────────────────────┤
//      │  Section: Exercise Name                                    │
//      │    Set | Previous | Weight | Reps | RPE   ← column header  │
//      │    1   175×8 @8  185  5    [chips] [chip] [✓]              │
//      │    2   175×8 @8  185  5    [chips] [chip] [✓]              │
//      │    [+ Add Set]                                             │
//      │  Section: Exercise Name                                    │
//      │    ...                                                     │
//      └────────────────────────────────────────────────────────────┘
//
//  The toolbar carries:
//    - Leading "Discard" (only when zero sets have been logged).
//    - Trailing "Finish" (always present; accent foreground).
//    - Principal (centered) — "Workout" headline + routine snapshot name
//      subtitle in `.caption .secondary`.
//
//  ## Rest timer integration (SESS-04)
//
//  Each `SessionLoggerView` instance owns one `RestTimerEngine` instance
//  via `RestTimerEngine.makeProduction()` — the factory wires the live
//  notification scheduler + live Live Activity controller in one call
//  (plan 02-03's surface).
//
//  - `commitSet(_:for:)` flips `isComplete = true`, writes `completedAt`,
//    saves the context, AND calls `engine.start(seconds:, exerciseName:)`.
//    The save MUST precede the engine start so the committed set is in the
//    store before the rest period begins (RESEARCH §6 Pitfall 2).
//
//  - Tapping the next set's weight/reps cell on a still-incomplete set
//    calls `engine.stop()` via the `onTapEmptyCell` closure. This is the
//    auto-stop-on-next-set-entry pattern (SESS-04).
//
//  - `finish()` and `discard()` both call `engine.stop()` to cancel any
//    pending lock-screen notification + end the Live Activity.
//
//  ## Finish / Discard semantics
//
//  - "Finish" → `confirmationDialog` with summary ("{N} sets logged ·
//    {elapsed time}"). On confirm: writes `session.completedAt = .now`,
//    `totalDurationSeconds`, dismisses.
//  - "Discard" (only when `loggedSetCount == 0`) → alert ("No data will
//    be saved."). On confirm: `ctx.delete(session)`, dismisses. The
//    cascade rule on `Session.exercises` automatically deletes the empty
//    `SessionExercise` rows (and their `SetEntry` rows by transitive
//    cascade).
//

import SwiftUI
import SwiftData

public struct SessionLoggerView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Bindable public var session: Session
    @State private var engine = RestTimerEngine.makeProduction()
    @State private var elapsedStart: Date
    @State private var presentingFinishConfirm = false
    @State private var presentingDiscardConfirm = false
    /// Wave-4 plan 04-02 — long-press "Swap Exercise…" target.
    /// `.sheet(item:)` presents `SwapExerciseSheet` against this.
    @State private var pendingSwap: SessionExercise?
    /// Wave-4 plan 04-02 — long-press "Remove from Session" target.
    /// `.alert` presents the destructive confirmation.
    @State private var pendingRemove: SessionExercise?

    public init(session: Session) {
        self.session = session
        self._elapsedStart = State(initialValue: session.startedAt)
    }

    public var body: some View {
        VStack(spacing: 0) {
            RestTimerOverlay(engine: engine)
                .padding(.top, 8)
            headerChips
            List {
                ForEach(sortedExercises) { se in
                    SessionExerciseCard(
                        sessionExercise: se,
                        engine: engine,
                        onCommitSet: { commitSet($0, for: se) },
                        onTapEmptyCell: { engine.stop() },
                        onSwap: { pendingSwap = $0 },
                        onRemove: { pendingRemove = $0 }
                    )
                }
                // Wave-4 plan 04-02 — bottom-of-list "+ Add Exercise"
                // affordance (SESS-06). Appends an unplanned
                // SessionExercise to the active session ONLY; the
                // source Routine is untouched (PITFALLS-doc #1).
                Section {
                    AddUnplannedExerciseButton(session: session)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Workout")                                            // UI-SPEC verbatim
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Workout").font(.headline)
                    Text(session.routineSnapshotName)                          // UI-SPEC verbatim subtitle
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if loggedSetCount == 0 {
                    Button("Discard") {                                        // UI-SPEC verbatim
                        presentingDiscardConfirm = true
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") {                                             // UI-SPEC verbatim
                    presentingFinishConfirm = true
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .confirmationDialog(
            "Finish Workout?",                                                 // UI-SPEC verbatim
            isPresented: $presentingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish") { finish() }                                      // UI-SPEC verbatim
            Button("Keep Logging", role: .cancel) {                            // UI-SPEC verbatim
                presentingFinishConfirm = false
            }
        } message: {
            Text("\(loggedSetCount) sets logged · \(elapsedLabel)")            // UI-SPEC verbatim format
        }
        .alert(
            "Discard Workout?",                                                // UI-SPEC verbatim
            isPresented: $presentingDiscardConfirm
        ) {
            Button("Discard", role: .destructive) { discard() }                // UI-SPEC verbatim
            Button("Cancel", role: .cancel) {                                  // UI-SPEC verbatim
                presentingDiscardConfirm = false
            }
        } message: {
            Text("No data will be saved.")                                     // UI-SPEC verbatim
        }
        // Wave-4 plan 04-02 — swap-exercise sheet (SESS-05). Bound to the
        // pendingSwap state, which is set by SessionExerciseCard's
        // long-press "Swap Exercise…" menu entry.
        .sheet(item: $pendingSwap) { se in
            SwapExerciseSheet(sessionExercise: se)
        }
        // Wave-4 plan 04-02 — remove-exercise destructive confirmation
        // (SESS-05/SESS-06 inverse). Bound to pendingRemove, set by
        // SessionExerciseCard's long-press "Remove from Session" menu.
        // UI-SPEC verbatim: title "Remove \"{name}\"?", body "Any logged
        // sets for this exercise will be discarded.", buttons
        // "Remove" (destructive) / "Cancel".
        .alert(
            "Remove \"\(pendingRemove?.exercise?.name ?? "")\"?",              // UI-SPEC verbatim
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            presenting: pendingRemove
        ) { se in
            Button("Remove", role: .destructive) { handleRemove(se) }          // UI-SPEC verbatim
            Button("Cancel", role: .cancel) {                                  // UI-SPEC verbatim
                pendingRemove = nil
            }
        } message: { _ in
            Text("Any logged sets for this exercise will be discarded.")       // UI-SPEC verbatim
        }
    }

    /// Wave-4 plan 04-02 — destructively removes a SessionExercise (and
    /// its owned SetEntry rows by cascade) from the active session.
    /// PITFALLS-doc #1 — the source RoutineExercise is untouched.
    /// Cascade rule on SessionExercise.sets is .cascade (plan 01-01 /
    /// SessionExercise.swift) → owned SetEntry rows go with it.
    private func handleRemove(_ se: SessionExercise) {
        ctx.delete(se)
        try? ctx.save()
        pendingRemove = nil
    }

    // MARK: - Derived state

    /// `SessionExercise` rows sorted by `orderIndex` for stable rendering.
    /// The snapshot order is locked at `SessionFactory.start` time and
    /// never re-shuffled by routine edits.
    private var sortedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Total committed sets across every exercise — drives the
    /// "Discard" button's visibility (only renders when zero) and the
    /// "Finish Workout?" confirmation body summary.
    private var loggedSetCount: Int {
        sortedExercises.reduce(0) { sum, se in
            sum + (se.sets ?? []).filter { $0.isComplete }.count
        }
    }

    // MARK: - Header

    /// Elapsed-time + exercise-progress + workout-notes chip row. Wrapped
    /// in `TimelineView(.periodic(from: elapsedStart, by: 1))` so the
    /// elapsed-time label re-renders once per second without a foreground
    /// `Timer` (RESEARCH §6 Pattern 2).
    @ViewBuilder private var headerChips: some View {
        TimelineView(.periodic(from: elapsedStart, by: 1)) { _ in
            HStack(spacing: 12) {                                              // UI-SPEC md
                HStack(spacing: 4) {                                           // UI-SPEC xs
                    Image(systemName: "clock")
                    Text(elapsedLabel)
                }
                Text("\(progressLabel)")                                       // "3 of 6"
                Button {
                    // Plan 04-03 — present WorkoutNotesSheet.
                } label: {
                    HStack(spacing: 4) {                                       // UI-SPEC xs
                        Image(systemName: "square.and.pencil")
                        Text("Notes")                                          // UI-SPEC verbatim caption
                    }
                }
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// "M:SS" elapsed label — computed off `Date.now` so it never drifts
    /// (PITFALLS-doc #4 — same Date-math pattern as the rest timer).
    private var elapsedLabel: String {
        let s = max(0, Int(Date.now.timeIntervalSince(elapsedStart)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "{N} of {M}" exercise-progress label. N = the next-incomplete
    /// exercise's 1-based index (or the last index when all are complete).
    private var progressLabel: String {
        let totalExercises = sortedExercises.count
        let completed = sortedExercises.prefix(while: { se in
            (se.sets ?? []).allSatisfy { $0.isComplete }
        }).count
        return "\(min(completed + 1, totalExercises)) of \(totalExercises)"
    }

    // MARK: - Mutating commands

    /// Commits a set: flips `isComplete = true`, writes `completedAt`,
    /// persists, and starts the rest timer. RESEARCH §6 Pitfall 2 — the
    /// save MUST precede `engine.start(...)` so the committed set is in
    /// the store before the rest period kicks off.
    private func commitSet(_ entry: SetEntry, for se: SessionExercise) {
        entry.isComplete = true
        entry.completedAt = .now
        try? ctx.save()
        let prescribed = max(1, se.prescribedRestSeconds)
        engine.start(seconds: prescribed, exerciseName: se.exercise?.name ?? "")
    }

    /// Marks the session finished. Writes `completedAt = .now` and the
    /// elapsed `totalDurationSeconds` (matches UI-SPEC § Session logger
    /// "Finish workout confirmation body" surface). Stops the rest timer
    /// to cancel any pending lock-screen notification.
    private func finish() {
        session.completedAt = .now
        session.totalDurationSeconds = Int(Date.now.timeIntervalSince(session.startedAt))
        engine.stop()
        try? ctx.save()
        dismiss()
    }

    /// Discards the active session. Only reachable from the Discard
    /// toolbar button, which only renders when `loggedSetCount == 0` — so
    /// no user data is at risk. The cascade rule on `Session.exercises`
    /// automatically deletes the empty `SessionExercise` rows + their
    /// (empty) `SetEntry` rows by transitive cascade.
    private func discard() {
        engine.stop()
        ctx.delete(session)
        try? ctx.save()
        dismiss()
    }
}

#Preview("session logger") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let session = Session()
    session.startedAt = .now.addingTimeInterval(-180)
    session.routineSnapshotName = "Push Day A"
    ctx.insert(session)
    let se = SessionExercise()
    se.session = session
    se.exercise = ex
    se.intentRaw = "strength"
    se.targetSets = 3
    se.prescribedRestSeconds = 180
    ctx.insert(se)
    for i in 0..<3 {
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = i
        ctx.insert(entry)
    }
    try? ctx.save()
    return NavigationStack {
        SessionLoggerView(session: session)
    }
    .modelContainer(container)
}
