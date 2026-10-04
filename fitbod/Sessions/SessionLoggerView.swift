//
//  SessionLoggerView.swift
//  fitbod
//
//  The active workout (Chalkline redesign of plan 04-01). Presented
//  full-screen by `RootView` through `WorkoutFlowView`, so it looks the same
//  whether it was started from a routine, Today, or restored on relaunch.
//
//  ## Layout
//
//      [⌄ minimize]        WORKOUT        [⋯] [Finish]
//      ┌ iron panel ──────────────────────────────────┐
//      │ PUSH DAY A                                    │
//      │ ELAPSED 32:14   SETS 7/14   VOLUME LB 8,450   │
//      │ ███████░░░░░░░                                │
//      └───────────────────────────────────────────────┘
//      Exercise sections (SessionExerciseCard) …
//      [+ Add exercise]  [FINISH WORKOUT]
//      ┌ rest dock (safe-area inset, thumb zone) ──────┐
//
//  ## Behaviour
//
//  - Completing a set validates (reps required; weight > 0 unless the lift
//    is bodyweight-based), saves immediately, fires a success haptic and
//    starts the rest timer from an absolute deadline tied to this session.
//    A failed completion outlines the missing field, shows an inline
//    message, focuses the field, and is announced to VoiceOver.
//  - Every edit is saved as it happens; closing or killing the app loses
//    nothing, and `RootView` reopens this screen on relaunch.
//  - The keyboard toolbar walks weight → reps → next open set.
//  - Finish confirms (with the count of unfinished sets that will be
//    dropped), then `WorkoutFinisher` stamps the session and the flow
//    switches to the summary. With nothing logged, Finish offers Discard.
//  - Minimize keeps the workout active; Today shows Resume.
//

import SwiftUI
import SwiftData
import UIKit

public struct SessionLoggerView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(RestTimerEngine.self) private var restTimer
    @Environment(AppRouter.self) private var router
    @Bindable public var session: Session
    @Query private var settingsList: [UserSettings]

    @FocusState private var focusedField: SetField?
    @State private var errors: [UUID: SetValidation] = [:]
    @State private var completedTick = 0
    @State private var errorTick = 0
    @State private var presentingFinish = false
    @State private var presentingDiscard = false
    @State private var presentingAddExercise = false
    @State private var presentingWorkoutNotes = false
    @State private var pendingSwap: SessionExercise?
    @State private var pendingRemove: SessionExercise?
    @State private var pendingPinnedNote: SessionExercise?
    @State private var pendingSetNote: SetEntry?

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    WorkoutHeaderPanel(session: session, unitLabel: unitLabel)
                        .chalkBareListRow()
                }

                if sortedExercises.isEmpty {
                    Section {
                        ChalkEmptyState(
                            systemImage: "dumbbell",
                            title: "No exercises",
                            message: "Add an exercise to keep logging, or discard this workout from the ⋯ menu."
                        )
                        .chalkBareListRow()
                    }
                }

                ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, se in
                    SessionExerciseCard(
                        sessionExercise: se,
                        exerciseIndex: index,
                        unitLabel: unitLabel(for: se),
                        nextSetID: nextSetID,
                        errors: errors,
                        focus: $focusedField,
                        onComplete: { complete($0, in: se) },
                        onUncomplete: { WorkoutLogging.uncomplete($0, context: ctx) },
                        onSetEdited: { edited($0, in: se) },
                        onSwap: { pendingSwap = $0 },
                        onRemove: { pendingRemove = $0 },
                        onEditPinnedNote: { pendingPinnedNote = $0 },
                        onEditSetNote: { pendingSetNote = $0 }
                    )
                }

                Section {
                    Button {
                        presentingAddExercise = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(.chalk(.secondary, fullWidth: true))
                    .accessibilityIdentifier("workout.addExercise")

                    Button("Finish workout") {
                        presentingFinish = true
                    }
                    .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                    .accessibilityIdentifier("workout.finishBottom")
                }
                .listRowInsets(EdgeInsets(top: Chalk.Space.xs, leading: 0, bottom: Chalk.Space.xs, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(Chalk.Space.lg)
            .chalkCanvasBackground()
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Out of the way while a number is being typed: on small
                // iPhones the dock would otherwise cover the row in focus.
                if focusedField == nil {
                    RestTimerDock(engine: restTimer)
                }
            }
            .animation(.easeInOut(duration: Chalk.Motion.standard), value: restTimer.isRunning)
            .navigationTitle("WORKOUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sensoryFeedback(.success, trigger: completedTick)
        .sensoryFeedback(.error, trigger: errorTick)
        .confirmationDialog(finishTitle, isPresented: $presentingFinish, titleVisibility: .visible) {
            if completedSetCount > 0 {
                Button("Finish workout") { finish() }
            } else {
                Button("Discard workout", role: .destructive) { discard() }
            }
            Button("Keep logging", role: .cancel) {}
        } message: {
            Text(finishMessage)
        }
        .alert("Discard workout?", isPresented: $presentingDiscard) {
            Button("Discard", role: .destructive) { discard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All sets logged in this workout will be deleted. Your routine is not affected.")
        }
        .alert(
            removeTitle,
            isPresented: Binding(
                get: { pendingRemove != nil },
                set: { if !$0 { pendingRemove = nil } }
            ),
            presenting: pendingRemove
        ) { se in
            Button("Remove", role: .destructive) {
                ctx.delete(se)
                try? ctx.save()
                pendingRemove = nil
            }
            Button("Cancel", role: .cancel) { pendingRemove = nil }
        } message: { _ in
            Text("Any logged sets for this exercise will be discarded.")
        }
        .sheet(isPresented: $presentingAddExercise) {
            ExercisePickerSheet(title: "Add exercise", allowsMultipleSelection: true) { exercises in
                for exercise in exercises {
                    WorkoutLogging.addExercise(exercise, to: session, context: ctx)
                }
            }
        }
        .sheet(item: $pendingSwap) { se in
            SwapExerciseSheet(sessionExercise: se)
        }
        .sheet(isPresented: $presentingWorkoutNotes) {
            WorkoutNotesSheet(session: session)
        }
        .sheet(item: $pendingPinnedNote) { se in
            PinnedNoteSheet(sessionExercise: se)
        }
        .sheet(item: $pendingSetNote) { entry in
            PerSetNoteSheet(entry: entry)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                focusedField = nil
                router.dismissWorkout()
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Minimize workout")
            .accessibilityIdentifier("workout.minimize")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    presentingWorkoutNotes = true
                } label: {
                    Label("Workout notes", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    presentingDiscard = true
                } label: {
                    Label("Discard workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Workout options")
            .accessibilityIdentifier("workout.options")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Finish") {
                presentingFinish = true
            }
            .fontWeight(.heavy)
            .accessibilityIdentifier("workout.finish")
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Next") { advanceFocus() }
                .accessibilityIdentifier("keyboard.next")
            Button("Done") { focusedField = nil }
                .fontWeight(.semibold)
                .accessibilityIdentifier("keyboard.done")
        }
    }

    // MARK: Derived

    private var sortedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var globalUnit: WeightUnit {
        settingsList.first?.weightUnit ?? .lb
    }

    private var unitLabel: String { globalUnit.rawValue }

    private func unitLabel(for se: SessionExercise) -> String {
        (se.exercise?.unitOverride ?? globalUnit).rawValue
    }

    /// Sets in logging order: each exercise's warm-ups, then working sets.
    private var orderedSets: [SetEntry] {
        sortedExercises.flatMap { se in
            WorkoutLogging.warmupSets(of: se) + WorkoutLogging.workingSets(of: se)
        }
    }

    /// The first open set — highlighted as "next".
    private var nextSetID: UUID? {
        orderedSets.first { !$0.isComplete }?.id
    }

    private var completedSetCount: Int {
        WorkoutFinisher.completedSetCount(in: session)
    }

    private var finishTitle: String {
        completedSetCount > 0 ? "Finish workout?" : "No sets logged yet"
    }

    private var finishMessage: String {
        let completed = completedSetCount
        guard completed > 0 else {
            return "Log at least one set to save this workout, or discard it."
        }
        let elapsed = ChalkFormat.clock(seconds: Int(Date.now.timeIntervalSince(session.startedAt)))
        let unfinished = WorkoutFinisher.unfinishedSetCount(in: session)
        var message = "\(completed) set\(completed == 1 ? "" : "s") logged · \(elapsed)."
        if unfinished > 0 {
            message += " \(unfinished) unfinished set\(unfinished == 1 ? "" : "s") will be removed."
        }
        return message
    }

    private var removeTitle: String {
        "Remove \"\(pendingRemove?.exercise?.name ?? "exercise")\"?"
    }

    // MARK: Actions

    private func complete(_ entry: SetEntry, in se: SessionExercise) {
        let result = WorkoutLogging.complete(entry, equipment: se.exercise?.equipment, context: ctx)
        if result == .ok {
            errors[entry.id] = nil
            focusedField = nil
            completedTick += 1
            if !entry.isWarmup {
                restTimer.start(
                    seconds: max(1, se.prescribedRestSeconds),
                    exerciseName: se.exercise?.name ?? "",
                    sessionID: session.id
                )
            }
        } else {
            errors[entry.id] = result
            errorTick += 1
            if let message = result.message(setLabel: label(for: entry, in: se)) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            focusedField = result == .missingReps ? .reps(entry.id) : .weight(entry.id)
        }
    }

    private func edited(_ entry: SetEntry, in se: SessionExercise) {
        if errors[entry.id] != nil {
            let validation = WorkoutLogging.validate(entry, equipment: se.exercise?.equipment)
            errors[entry.id] = validation == .ok ? nil : validation
        }
        try? ctx.save()
    }

    private func label(for entry: SetEntry, in se: SessionExercise) -> String {
        if entry.isWarmup {
            let index = WorkoutLogging.warmupSets(of: se).firstIndex { $0.id == entry.id } ?? 0
            return "W\(index + 1)"
        }
        let index = WorkoutLogging.workingSets(of: se).firstIndex { $0.id == entry.id } ?? 0
        return "\(index + 1)"
    }

    private func advanceFocus() {
        let order: [SetField] = orderedSets
            .filter { !$0.isComplete }
            .flatMap { [SetField.weight($0.id), SetField.reps($0.id)] }
        guard let current = focusedField,
              let index = order.firstIndex(of: current),
              index + 1 < order.count else {
            focusedField = nil
            return
        }
        focusedField = order[index + 1]
    }

    private func finish() {
        focusedField = nil
        restTimer.stop(ifBelongsTo: session.id)
        WorkoutFinisher.finish(session, context: ctx)
    }

    private func discard() {
        focusedField = nil
        restTimer.stop(ifBelongsTo: session.id)
        router.pendingDiscard = session
        router.dismissWorkout()
    }
}

// MARK: - Header panel

/// Iron panel at the top of the workout: routine snapshot name, live
/// elapsed time, completed / planned sets, volume, progress.
struct WorkoutHeaderPanel: View {
    @Bindable var session: Session
    let unitLabel: String

    var body: some View {
        ChalkPanel {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                let stats = WorkoutStats.compute(for: session, now: context.date)
                VStack(alignment: .leading, spacing: Chalk.Space.md) {
                    Text(session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName)
                        .font(.chalkDisplay)
                        .textCase(.uppercase)
                        .foregroundStyle(.chalkOnPanel)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("workout.title")
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Chalk.Space.md) {
                            metrics(stats)
                        }
                        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                            metrics(stats)
                        }
                    }
                    ChalkProgressBar(
                        progress: stats.plannedSets > 0 ? Double(stats.completedSets) / Double(stats.plannedSets) : 0
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func metrics(_ stats: WorkoutStats) -> some View {
        ChalkMetric("Elapsed", value: ChalkFormat.clock(seconds: stats.durationSeconds), onPanel: true)
        ChalkMetric("Sets", value: "\(stats.completedSets)/\(stats.plannedSets)", onPanel: true)
            .accessibilityIdentifier("workout.setsProgress")
        ChalkMetric("Volume \(unitLabel)", value: ChalkFormat.volume(stats.volume), onPanel: true)
    }
}

// MARK: - Flow

/// Cover content: the logger while the workout is open, the summary once
/// it is finished.
struct WorkoutFlowView: View {
    @Bindable var session: Session

    var body: some View {
        if session.completedAt == nil {
            SessionLoggerView(session: session)
        } else {
            NavigationStack {
                WorkoutSummaryView(session: session, presentation: .justFinished)
            }
        }
    }
}

#Preview("Workout — in progress") {
    let container = PreviewModelContainer.makeDemo()
    let session = PreviewModelContainer.demoActiveWorkout(in: container)
    return Group {
        if let session {
            WorkoutFlowView(session: session)
        }
    }
    .environment(AppRouter())
    .environment(RestTimerEngine(scheduler: NoopNotificationScheduler()))
    .modelContainer(container)
}
