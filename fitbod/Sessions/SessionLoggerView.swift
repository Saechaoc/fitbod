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
// M1 logger additions:
//   - RestTimerOverlay is mounted with .safeAreaInset(edge: .bottom) (the
//     header note above claimed this mount, but the body never had it).
//   - The rest timer is bound to the session id and persisted as a
//     deadline (RestTimerStore). It is restored on appear and every time
//     the scene becomes active, so it survives background and relaunch.
//   - Sets can be un-completed (tap the checkmark) and deleted (swipe);
//     both persist immediately via SessionSetActions. Weight/reps edits
//     save when a field loses focus and when the app leaves the foreground.
//   - Finish presents SessionDetailView as the workout summary.
//   - Finish with no logged work set offers Discard workout instead
//     (decision 6), and the Finish and Discard dialogs show a visible
//     Keep logging, because iOS 26 hides cancel-role buttons. Discard is
//     now a confirmation dialog too.
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isKeyboardVisible) private var isKeyboardVisible

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
    @State private var presentingSummary = false

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
                        onTapEmptyCell: { stopRestIfRunning() },
                        onSwap: { pendingSwap = $0 },
                        onRemove: { pendingRemove = $0 },
                        onEditPinnedNote: { pendingPinnedNote = $0 },
                        onUncompleteSet: { uncompleteSet($0) },
                        onDeleteSet: { deleteSet($0) },
                        onAddSet: { SessionSetActions.addSet(to: $0, context: ctx) },
                        onEditCommitted: { try? ctx.save() }
                    )
                }
                Section {
                    AddUnplannedExerciseButton(session: session)
                        .padding(16)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.bruPaper)
                }
                .listSectionSeparator(.hidden)
            }
            // Full-width exercise blocks on paper, ruled apart: no inset
            // grouped cards, no system gray.
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.bruPaper)
            .scrollDismissesKeyboard(.interactively)
        }
        // The workout gets the full height; the header's ‹ leads back out.
        .bruTabBarHidden()
        // Rest timer dock — bottom edge, above the home indicator, in
        // thumb reach. Renders nothing while no rest is running, and steps
        // aside while the keyboard is up so it never covers the set being
        // typed into (the countdown keeps running).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isKeyboardVisible {
                RestTimerOverlay(engine: engine)
            }
        }
        .animation(.easeOut(duration: 0.2), value: engine.isRunning)
        // Number pads have no return key: give the keyboard a Done.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    dismissKeyboard()
                } label: {
                    Text("DONE")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruInk)
                }
            }
        }
        // BRU header replaces .navigationTitle + .toolbar principal block
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            bruHeader
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("workout.header")
        }
        // Phase 6 plan 06-07 — PR banner above the content (anti-layout-shift)
        .safeAreaInset(edge: .top, spacing: 0) {
            InSessionPRBanner(state: prState)
        }
        // Finish workout confirmation (system chrome acceptable per UI-SPEC line 261).
        // With no logged work set there is nothing to save, so it offers
        // Discard workout instead of Finish (decision 6); this dialog is the
        // question, so Discard workout deletes at once. iOS 26 hides
        // cancel-role buttons, so Keep logging has no role.
        .confirmationDialog(
            "Finish workout?",                                                   // UI-SPEC verbatim
            isPresented: $presentingFinishConfirm,
            titleVisibility: .visible
        ) {
            if session.loggedSetCount == 0 {
                Button("Discard workout", role: .destructive) { discard() }
            } else {
                Button("Finish") { finish() }                                    // UI-SPEC verbatim
            }
            Button("Keep logging") {                                             // UI-SPEC verbatim
                presentingFinishConfirm = false
            }
        } message: {
            Text("\(BRUCountLabel.text(session.loggedSetCount, "set")) logged · \(elapsedLabel)") // UI-SPEC format
        }
        // Discard workout confirmation. A dialog like Finish, not an alert:
        // an alert adds its own visible Cancel beside Keep logging.
        .confirmationDialog(
            "Discard workout?",                                                  // UI-SPEC verbatim
            isPresented: $presentingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { discard() }                  // UI-SPEC verbatim
            Button("Keep logging") {
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
            "Remove \"\(pendingRemove?.displayName ?? "")\"?",                  // UI-SPEC verbatim
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
        // Workout summary after Finish. DONE closes the summary and the logger.
        .fullScreenCover(isPresented: $presentingSummary, onDismiss: { dismiss() }) {
            SessionDetailView(session: session, onDone: { presentingSummary = false })
        }
        // Phase 6 plan 06-07 — PR state seeded once on appear.
        // Rest timer: bind to this session and restore any persisted rest.
        .task {
            engine.bind(sessionID: session.id)
            prState.prTable = await SessionFactory.seedPRTable(for: session, context: ctx)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Back from background or the app switcher: re-sync the
                // countdown from the stored deadline.
                engine.restore()
            case .inactive, .background:
                // Flush any in-flight weight/reps edit before iOS may
                // suspend or kill the app.
                try? ctx.save()
            @unknown default:
                break
            }
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
                if session.loggedSetCount == 0 {
                    Button("Discard", role: .destructive) {                      // UI-SPEC verbatim
                        presentingDiscardConfirm = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            // Lines 2-3: WorkoutHeaderToolbar — extracted per UI-SPEC line 584 (Plan 02.1-08)
            // Wrapped in TimelineView so elapsed label re-renders per second
            TimelineView(.periodic(from: elapsedStart, by: 1)) { _ in
                WorkoutHeaderToolbar(session: session, elapsedLabel: elapsedLabel) // UI-SPEC line 363-366 + 584
            }

            BRUDivider(.ink)
        }
    }

    // MARK: - Derived state

    private var sortedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
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
        guard SessionSetActions.canComplete(entry) else { return }
        // The set is done, so typing is too: drop the keyboard so the rest
        // dock and the next set are in view.
        dismissKeyboard()
        // Flips isComplete, stamps completedAt and saves BEFORE the rest
        // timer starts (RESEARCH §6 Pitfall 2).
        SessionSetActions.complete(entry, at: .now, context: ctx)
        prState.observeSave(set: entry)
        let prescribed = max(1, se.prescribedRestSeconds)
        engine.start(seconds: prescribed, exerciseName: se.displayName)
    }

    /// Tap on a completed checkmark. The rest timer is left alone: undoing
    /// a mis-tap must not restart (or cancel) the rest already running.
    private func uncompleteSet(_ entry: SetEntry) {
        SessionSetActions.uncomplete(entry, context: ctx)
        reseedPRTable()
    }

    private func deleteSet(_ entry: SetEntry) {
        SessionSetActions.delete(entry, context: ctx)
        reseedPRTable()
    }

    /// Un-completing or deleting a set can lower a PR the live table
    /// already recorded; rebuild it from what is actually logged.
    private func reseedPRTable() {
        Task {
            prState.prTable = await SessionFactory.seedPRTable(for: session, context: ctx)
        }
    }

    /// Typing into the next set's empty cell ends the rest (SESS-04).
    private func stopRestIfRunning() {
        if engine.isRunning { engine.stop() }
    }

    /// Ends editing in whichever weight or reps field has focus; the
    /// field's focus change then persists the edit.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private func finish() {
        session.completedAt = .now
        session.totalDurationSeconds = Int(Date.now.timeIntervalSince(session.startedAt))
        engine.stop()
        try? ctx.save()
        presentingSummary = true
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
