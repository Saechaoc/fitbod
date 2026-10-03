// SessionTemplateDetailView.swift
// fitbod
//
// Session detail (UI term "Session"; code entity SessionTemplate). Reached by
// tapping a session inside a routine or on Today. Shows the ordered
// prescription and the last time it was done, and is where a workout starts
// outside the block schedule.
//
// Layout (top to bottom):
//   BRUHeaderBar  ‹ BACK · SESSION · EDIT
//   Title block   condensed name (wraps), summary line, last-done line
//   Exercise list numbered rows: name (wraps) + prescription line
//   Bottom bar    START WORKOUT ▸ (signal, lg) pinned above the home indicator
//
// Starting goes through WorkoutStarter so a workout already in progress is
// offered for resume instead of failing silently.

import SwiftUI
import SwiftData

public struct SessionTemplateDetailView: View {

    @Environment(\.modelContext) private var ctx
    @Bindable public var template: SessionTemplate

    @State private var startedSession: Session? = nil
    @State private var inProgressConflict: Session? = nil
    @State private var startError: String? = nil
    @State private var presentingEditor = false

    public init(template: SessionTemplate) {
        self.template = template
    }

    private var orderedExercises: [SessionExerciseTemplate] {
        (template.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var summary: SessionTemplateSummary {
        SessionTemplateSummary(template: template)
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar.slots(
                left: .back,
                center: "Session",
                right: .action("Edit") { presentingEditor = true }
            )

            ScrollView {
                VStack(spacing: 0) {
                    titleBlock
                    BRUDivider(.ink)
                    exerciseList
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) { startBar }
        .navigationDestination(item: $startedSession) { session in
            SessionLoggerView(session: session)
        }
        .sheet(isPresented: $presentingEditor) {
            NavigationStack {
                RoutineBuilderView(draft: RoutineDraft(routine: template), editing: template)
            }
        }
        .alert(
            "Workout in progress",
            isPresented: Binding(
                get: { inProgressConflict != nil },
                set: { if !$0 { inProgressConflict = nil } }
            ),
            presenting: inProgressConflict
        ) { active in
            Button("Resume \(active.routineSnapshotName)") {
                startedSession = active
                inProgressConflict = nil
            }
            Button("Cancel", role: .cancel) { inProgressConflict = nil }
        } message: { _ in
            Text("Finish or discard the current workout before starting another.")
        }
        .alert(
            "Couldn't start workout",
            isPresented: Binding(
                get: { startError != nil },
                set: { if !$0 { startError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { startError = nil }
        } message: {
            Text(startError ?? "")
        }
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.name.isEmpty ? "Untitled session" : template.name)
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(summary.line)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)

            Text(lastDoneLine)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var lastDoneLine: String {
        guard let last = WorkoutStarter.lastCompletedSession(of: template, in: ctx) else {
            return "Not done yet"
        }
        let date = last.startedAt.formatted(.dateTime.month(.abbreviated).day())
        let relative = last.startedAt.formatted(.relative(presentation: .named))
        return "Last done · \(date) · \(relative)"
    }

    // MARK: - Exercise list

    @ViewBuilder
    private var exerciseList: some View {
        let exercises = orderedExercises
        if exercises.isEmpty {
            VStack(spacing: 12) {
                Text("No exercises yet")
                    .font(BRUFont.condensedHeading)
                    .foregroundStyle(Color.bruInk)
                Text("Add exercises to this session before you start it.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
                BRUButton("Add exercises", kind: .ghost) { presentingEditor = true }
                    .frame(maxWidth: 240)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 16)
        } else {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, item in
                exerciseRow(index: index, item: item)
                if index < exercises.count - 1 {
                    BRUDivider(.hair)
                }
            }
            BRUDivider(.ink)
        }
    }

    private func exerciseRow(index: Int, item: SessionExerciseTemplate) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(BRUFont.condensedLabel)
                .foregroundStyle(Color.bruMuted)
                .frame(minWidth: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.exercise?.name ?? "Missing exercise")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(prescriptionLine(
                    sets: item.targetSets,
                    repsLow: item.targetRepsLow,
                    repsHigh: item.targetRepsHigh,
                    rpe: item.targetRPE,
                    restSeconds: item.prescribedRestSeconds
                ))
                .font(BRUFont.labelSmall)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Start bar

    private var startBar: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)
            BRUButton("Start workout ▸", kind: .signal, size: .lg) { start() }
                .disabled(orderedExercises.isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityHint("Starts logging this session now")
        }
        .background(Color.bruPaper.ignoresSafeArea(edges: .bottom))
    }

    private func start() {
        switch WorkoutStarter.start(template, context: ctx) {
        case .started(let session):
            startedSession = session
        case .alreadyInProgress(let active):
            inProgressConflict = active
        case .emptyTemplate:
            startError = "Add at least one exercise to this session first."
        case .failed(let message):
            startError = message
        }
    }
}

#if DEBUG
#Preview("Session detail") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let template = SessionTemplate()
    ctx.insert(template)
    template.name = "Push A · Chest, Shoulders & Triceps"
    let exercises = (try? ctx.fetch(FetchDescriptor<Exercise>())) ?? []
    for (i, exercise) in exercises.enumerated() {
        let item = SessionExerciseTemplate()
        ctx.insert(item)
        item.exercise = exercise
        item.sessionTemplate = template
        item.orderIndex = i
        item.targetSets = 4
        item.targetRepsLow = 6
        item.targetRepsHigh = 8
        item.targetRPE = 8
        item.prescribedRestSeconds = 180
    }
    return NavigationStack { SessionTemplateDetailView(template: template) }
        .modelContainer(container)
}
#endif
