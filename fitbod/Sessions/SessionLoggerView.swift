// SessionLoggerView.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 31).
// UI-SPEC v2 § Session logger line 355-396.
//
// The user-facing centerpiece of Phase 2: the active workout-logging surface
// bound to a @Bindable Session.
//
// KEY CHANGES from v1:
//   - .navigationTitle("Workout") + .toolbar principal block REMOVED
//   - Image(systemName: "clock") + headerChips REMOVED
//   - Color.accentColor on "Finish" button REMOVED
//   - REPLACED with .safeAreaInset(edge: .top) BRUHeaderBar + 3-line principal block:
//       Line 1: BRUHeaderBar("Workout", left: "‹", right: "•••")
//       Line 2: HStack { routineSnapshotName (displayMedium) + elapsed (bodyEmphasis monoMuted right) }
//       Line 3: IntentChip(intent: session.intent)
//   - Finish/Discard menu moves into right HeaderAction "•••" onTap → confirmationDialog
//   - Workout notes moves into "•••" menu per UI-SPEC line 361
//
// PRESERVED VERBATIM:
//   - @Bindable Session, SessionTimerState, RestTimerEngine wiring
//   - All .confirmationDialog + .alert blocks (system chrome acceptable per UI-SPEC line 261)
//   - .safeAreaInset(edge: .bottom) RestTimerOverlay mount
//   - .safeAreaInset(edge: .top) InSessionPRBanner mount (Phase 6 plan 06-07)
//   - commitSet, finish, discard, handleRemove semantics
//   - pendingSwap, pendingRemove, pendingPinnedNote sheets
//   - prState InSessionPRState + .task seed
//
// BRU contract: NO navigationTitle / NO .toolbar with system chrome
//               NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) in chrome / NO .font(.body/.headline/.title/.caption)
//               NO .buttonStyle(.bordered) / NO Color(.system*)

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
    @State private var presentingMenu = false
    @State private var pendingSwap: SessionExercise?
    @State private var pendingRemove: SessionExercise?
    @State private var presentingWorkoutNotes = false
    @State private var pendingPinnedNote: SessionExercise?

    /// Phase 6 plan 06-07 — in-session PR banner state.
    @State private var prState = InSessionPRState()

    public init(session: Session) {
        self.session = session
        self._elapsedStart = State(initialValue: session.startedAt)
    }

    public var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(sortedExercises) { se in
                    SessionExerciseCard(
                        sessionExercise: se,
                        engine: engine,
                        onCommitSet: { commitSet($0, for: se) },
                        onTapEmptyCell: { engine.stop() },
                        onSwap: { pendingSwap = $0 },
                        onRemove: { pendingRemove = $0 },
                        onEditPinnedNote: { pendingPinnedNote = $0 }
                    )
                }
                Section {
                    AddUnplannedExerciseButton(session: session)
                }
            }
            .listStyle(.insetGrouped)
        }
        // BRU header replaces .navigationTitle + .toolbar principal block
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            bruHeader
        }
        // Phase 6 plan 06-07 — PR banner above the content (anti-layout-shift)
        .safeAreaInset(edge: .top, spacing: 0) {
            InSessionPRBanner(state: prState)
        }
        // Finish workout confirmation (system chrome acceptable per UI-SPEC line 261)
        .confirmationDialog(
            "Finish workout?",                                                   // UI-SPEC verbatim
            isPresented: $presentingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish") { finish() }                                        // UI-SPEC verbatim
            Button("Keep logging", role: .cancel) {                              // UI-SPEC verbatim
                presentingFinishConfirm = false
            }
        } message: {
            Text("\(loggedSetCount) sets logged · \(elapsedLabel)")              // UI-SPEC verbatim format
        }
        // Discard workout confirmation
        .alert(
            "Discard workout?",                                                  // UI-SPEC verbatim
            isPresented: $presentingDiscardConfirm
        ) {
            Button("Discard", role: .destructive) { discard() }                  // UI-SPEC verbatim
            Button("Cancel", role: .cancel) {                                    // UI-SPEC verbatim
                presentingDiscardConfirm = false
            }
        } message: {
            Text("No data will be saved.")                                       // UI-SPEC verbatim
        }
        // Swap-exercise sheet
        .sheet(item: $pendingSwap) { se in
            SwapExerciseSheet(sessionExercise: se)
        }
        // Workout-level notes sheet
        .sheet(isPresented: $presentingWorkoutNotes) {
            WorkoutNotesSheet(session: session)
        }
        // Pinned per-exercise note sheet
        .sheet(item: $pendingPinnedNote) { se in
            PinnedNoteSheet(sessionExercise: se)
        }
        // Remove-exercise destructive confirmation
        .alert(
            "Remove \"\(pendingRemove?.exercise?.name ?? "")\"?",                // UI-SPEC verbatim
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            presenting: pendingRemove
        ) { se in
            Button("Remove", role: .destructive) { handleRemove(se) }            // UI-SPEC verbatim
            Button("Cancel", role: .cancel) {                                    // UI-SPEC verbatim
                pendingRemove = nil
            }
        } message: { _ in
            Text("Any logged sets for this exercise will be discarded.")         // UI-SPEC verbatim
        }
        // Phase 6 plan 06-07 — PR state seeded once on appear
        .task {
            prState.prTable = await SessionFactory.seedPRTable(for: session, context: ctx)
        }
    }

    // MARK: - BRU Header

    /// BRUHeaderBar + 3-line principal block per UI-SPEC line 358-363.
    ///
    /// Line 1: BRUHeaderBar("Workout", left: "‹", right: "•••")
    /// Line 2: HStack { routineSnapshotName (displayMedium) | elapsed (bodyEmphasis muted) }
    /// Line 3: IntentChip
    @ViewBuilder private var bruHeader: some View {
        VStack(spacing: 0) {
            // Line 1: BRUHeaderBar — "‹" dismiss left, "Workout" center, "•••" menu right
            BRUHeaderBar(
                left: HeaderAction("‹") { dismiss() },                           // UI-SPEC verbatim
                center: "Workout",                                               // UI-SPEC verbatim
                right: HeaderAction("•••") { presentingMenu = true }            // UI-SPEC verbatim
            )
            .confirmationDialog(
                "Workout",
                isPresented: $presentingMenu,
                titleVisibility: .hidden
            ) {
                Button("Workout notes") { presentingWorkoutNotes = true }        // UI-SPEC verbatim
                Button("Finish") { presentingFinishConfirm = true }              // UI-SPEC verbatim
                if loggedSetCount == 0 {
                    Button("Discard", role: .destructive) {                      // UI-SPEC verbatim
                        presentingDiscardConfirm = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            // Lines 2-3: 3-line principal block below the BRUHeaderBar
            // Wrapped in TimelineView so elapsed label re-renders per second
            TimelineView(.periodic(from: elapsedStart, by: 1)) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(session.routineSnapshotName)                        // UI-SPEC line 362
                            .font(BRUFont.displayMedium)
                            .foregroundStyle(Color.bruInk)
                        Spacer()
                        Text(elapsedLabel)                                       // "32:14" per UI-SPEC
                            .font(BRUFont.bodyEmphasis)
                            .monospacedDigit()
                            .foregroundStyle(Color.bruMuted)
                    }
                    IntentChip(intent: session.intent)                           // Line 363 — UI-SPEC
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.bruPaper)
            }

            BRUDivider(.ink)
        }
    }

    // MARK: - Derived state

    private var sortedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var loggedSetCount: Int {
        sortedExercises.reduce(0) { sum, se in
            sum + (se.sets ?? []).filter { $0.isComplete }.count
        }
    }

    /// "M:SS" elapsed label — computed off Date.now (matches PITFALLS-doc #4).
    private var elapsedLabel: String {
        let s = max(0, Int(Date.now.timeIntervalSince(elapsedStart)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Mutating commands

    /// Commits a set: flips isComplete, saves, observes for PR detection, starts rest timer.
    /// RESEARCH §6 Pitfall 2 — save MUST precede engine.start.
    private func commitSet(_ entry: SetEntry, for se: SessionExercise) {
        entry.isComplete = true
        entry.completedAt = .now
        try? ctx.save()
        prState.observeSave(set: entry)
        let prescribed = max(1, se.prescribedRestSeconds)
        engine.start(seconds: prescribed, exerciseName: se.exercise?.name ?? "")
    }

    private func finish() {
        session.completedAt = .now
        session.totalDurationSeconds = Int(Date.now.timeIntervalSince(session.startedAt))
        engine.stop()
        try? ctx.save()
        dismiss()
    }

    private func discard() {
        engine.stop()
        ctx.delete(session)
        try? ctx.save()
        dismiss()
    }

    private func handleRemove(_ se: SessionExercise) {
        ctx.delete(se)
        try? ctx.save()
        pendingRemove = nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("session logger") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let session = Session()
    session.startedAt = .now.addingTimeInterval(-180)
    session.routineSnapshotName = "Push Day A"
    session.intentRaw = Intent.strength.rawValue
    ctx.insert(session)
    let se = SessionExercise()
    se.session = session
    se.exercise = ex
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
#endif
