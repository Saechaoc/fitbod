//
//  RoutineDetailView.swift
//  fitbod
//
//  A routine at a glance before training: display title, meta line, the
//  ordered exercise table (# · exercise · target), notes, and a thumb-zone
//  START WORKOUT bar. Edit opens the builder; the ⋯ menu duplicates,
//  moves, or deletes.
//
//  Starting snapshots the routine into a new session (SessionFactory), so
//  later edits here never rewrite a logged workout.
//

import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine

    @Query(sort: \RoutineFolder.sortOrder) private var folders: [RoutineFolder]
    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var finishedSessions: [Session]

    @State private var editing = false
    @State private var moving = false
    @State private var confirmingDelete = false
    @State private var startFailure: WorkoutStartFailure?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Chalk.Space.xl) {
                ChalkScreenHeader(routine.name, subtitle: RoutineSummary.line(for: routine, lastDone: lastDone))

                if sortedExercises.isEmpty {
                    ChalkEmptyState(
                        systemImage: "dumbbell",
                        title: "No exercises",
                        message: "Add exercises to this routine before starting a workout.",
                        primaryTitle: "Edit routine",
                        primaryAction: { editing = true }
                    )
                } else {
                    exerciseTable
                }

                if let notes = routine.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                        ChalkSectionHeader("Notes")
                        Text(notes)
                            .font(.chalkBody)
                            .foregroundStyle(.chalkInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, Chalk.Space.gutter)
            .padding(.vertical, Chalk.Space.lg)
        }
        .background {
            Color.chalkCanvas.ignoresSafeArea()
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                    .accessibilityIdentifier("routine.edit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        RoutineDuplicator.duplicate(routine: routine, context: ctx)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button {
                        moving = true
                    } label: {
                        Label("Move to folder…", systemImage: "folder")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete routine", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Routine options")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChalkBottomBar {
                Button {
                    startFailure = WorkoutLauncher.start(routine, context: ctx, router: router)
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                }
                .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                .disabled(sortedExercises.isEmpty)
                .accessibilityIdentifier("routine.startWorkout")
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                RoutineBuilderView(draft: RoutineDraft(routine: routine), editing: routine)
            }
        }
        .sheet(isPresented: $moving) {
            MoveRoutineSheet(routine: routine, folders: folders)
        }
        .alert("Delete \"\(routine.name)\"?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                let target = routine
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    RoutineStore.delete(target, context: ctx)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Past workouts from this routine stay in History.")
        }
        .workoutStartAlert($startFailure)
    }

    private var sortedExercises: [RoutineExercise] {
        (routine.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var lastDone: Date? {
        finishedSessions.first { $0.sourceRoutineID == routine.id }?.startedAt
    }

    private var exerciseTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Chalk.Space.sm) {
                Text("#").frame(width: 24, alignment: .leading)
                Text("Exercise")
                Spacer(minLength: Chalk.Space.sm)
                Text("Target")
            }
            .chalkLabelStyle()
            .padding(.bottom, Chalk.Space.xs)
            Rectangle().fill(Color.chalkInk).frame(height: Chalk.Line.strong)

            ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.sm) {
                    Text("\(index + 1)")
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                        .frame(width: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                        Text(item.exercise?.name ?? "Removed exercise")
                            .font(.chalkHeadline)
                            .foregroundStyle(.chalkInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.meta(for: item))
                            .font(.chalkFootnote)
                            .foregroundStyle(.chalkInk2)
                    }
                    Spacer(minLength: Chalk.Space.sm)
                    Text(Self.target(for: item))
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                }
                .padding(.vertical, Chalk.Space.md)
                .accessibilityElement(children: .combine)
                Rectangle().fill(Color.chalkDivider).frame(height: Chalk.Line.hairline)
            }
        }
    }

    static func target(for item: RoutineExercise) -> String {
        let reps = item.targetRepsLow == item.targetRepsHigh ? "\(item.targetRepsLow)" : "\(item.targetRepsLow)–\(item.targetRepsHigh)"
        return "\(item.targetSets) × \(reps)"
    }

    static func meta(for item: RoutineExercise) -> String {
        var parts = [item.intent.rawValue.capitalized]
        if let rpe = item.targetRPE {
            parts.append("RPE \(ChalkFormat.rpe(rpe))")
        }
        parts.append("rest \(ChalkFormat.duration(seconds: item.prescribedRestSeconds))")
        return parts.joined(separator: " · ")
    }
}

#Preview("Routine detail — demo") {
    let container = PreviewModelContainer.makeDemo()
    let routine = try? container.mainContext.fetch(FetchDescriptor<Routine>()).first
    return NavigationStack {
        if let routine {
            RoutineDetailView(routine: routine)
        }
    }
    .environment(AppRouter())
    .modelContainer(container)
}
