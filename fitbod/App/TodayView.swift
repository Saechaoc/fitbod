//
//  TodayView.swift
//  fitbod
//
//  Today tab — the launch screen.
//
//    - Active workout: iron "IN PROGRESS" card with elapsed time, sets,
//      live rest countdown, progress, RESUME (primary) and Discard.
//    - Otherwise: START A WORKOUT — each routine with a one-tap Start.
//      No routines yet → empty state that opens the routine builder.
//    - THIS WEEK — workouts, sets, volume.
//    - LAST WORKOUT — opens its summary.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(AppRouter.self) private var router
    @Environment(RestTimerEngine.self) private var restTimer

    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]
    @Query(
        filter: #Predicate<Session> { $0.completedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var finishedSessions: [Session]
    @Query(sort: \Routine.name) private var routines: [Routine]
    @Query private var settingsList: [UserSettings]

    @State private var startFailure: WorkoutStartFailure?
    @State private var discardTarget: Session?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.todayPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Chalk.Space.xl) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .chalkLabelStyle()

                    if let active = activeSessions.first {
                        ActiveWorkoutCard(
                            session: active,
                            restTimer: restTimer,
                            onResume: { router.present(workout: active) },
                            onDiscard: { discardTarget = active }
                        )
                    } else {
                        quickStart
                    }

                    thisWeek

                    if let last = finishedSessions.first {
                        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                            ChalkSectionHeader("Last workout")
                            NavigationLink(value: AppRoute.workoutSummary(last)) {
                                ChalkCard {
                                    HStack {
                                        HistoryRow(session: last, unitLabel: unitLabel)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(.chalkInk3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.lastWorkout")
                        }
                    }
                }
                .padding(.horizontal, Chalk.Space.gutter)
                .padding(.bottom, Chalk.Space.xxl)
            }
            .background {
                Color.chalkCanvas.ignoresSafeArea()
            }
            .navigationTitle("TODAY")
            .appRouteDestinations()
            .workoutStartAlert($startFailure)
            .alert(
                "Discard workout?",
                isPresented: Binding(
                    get: { discardTarget != nil },
                    set: { if !$0 { discardTarget = nil } }
                ),
                presenting: discardTarget
            ) { session in
                Button("Discard", role: .destructive) {
                    restTimer.stop(ifBelongsTo: session.id)
                    WorkoutFinisher.discard(session, context: ctx)
                    discardTarget = nil
                }
                Button("Cancel", role: .cancel) { discardTarget = nil }
            } message: { _ in
                Text("All sets logged in this workout will be deleted. Your routine is not affected.")
            }
        }
    }

    // MARK: Quick start

    @ViewBuilder
    private var quickStart: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Start a workout")
            if routines.isEmpty {
                ChalkEmptyState(
                    systemImage: "list.bullet.rectangle",
                    title: "No routines yet",
                    message: "Build a routine — exercises in order with target sets, reps and rest — then start it here in one tap.",
                    primaryTitle: "New routine",
                    primaryAction: {
                        router.pendingNewRoutine = true
                        router.selectedTab = .routines
                    }
                )
            } else {
                ForEach(routines.prefix(6)) { routine in
                    ChalkCard {
                        HStack(spacing: Chalk.Space.md) {
                            NavigationLink(value: AppRoute.routine(routine)) {
                                VStack(alignment: .leading, spacing: Chalk.Space.xxs) {
                                    Text(routine.name)
                                        .font(.chalkHeadline)
                                        .foregroundStyle(.chalkInk)
                                        .multilineTextAlignment(.leading)
                                    Text(RoutineSummary.line(for: routine, lastDone: lastDone(routine)))
                                        .font(.chalkFootnote)
                                        .foregroundStyle(.chalkInk2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: Chalk.Size.minTouch, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button("Start") {
                                startFailure = WorkoutLauncher.start(routine, context: ctx, router: router)
                            }
                            .buttonStyle(.chalk(.primary, size: .compact))
                            .accessibilityLabel(Text("Start \(routine.name)"))
                            .accessibilityIdentifier("today.start.\(routine.name)")
                        }
                    }
                }
            }
        }
    }

    // MARK: This week

    private var thisWeek: some View {
        let week = weekTotals
        return VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("This week")
            HStack(spacing: Chalk.Space.sm) {
                ChalkMetricTile("Workouts", value: "\(week.workouts)")
                ChalkMetricTile("Sets", value: "\(week.sets)")
                ChalkMetricTile("Vol \(unitLabel)", value: ChalkFormat.volume(week.volume))
            }
        }
    }

    private var weekTotals: (workouts: Int, sets: Int, volume: Double) {
        var cal = Calendar.current
        cal.firstWeekday = (settingsList.first?.weekStartsMonday ?? true) ? 2 : 1
        guard let interval = cal.dateInterval(of: .weekOfYear, for: .now) else { return (0, 0, 0) }
        let inWeek = finishedSessions.filter { interval.contains($0.startedAt) }
        var sets = 0
        var volume = 0.0
        for session in inWeek {
            let stats = WorkoutStats.compute(for: session)
            sets += stats.completedSets
            volume += stats.volume
        }
        return (inWeek.count, sets, volume)
    }

    private var unitLabel: String {
        (settingsList.first?.weightUnit ?? .lb).rawValue
    }

    private func lastDone(_ routine: Routine) -> Date? {
        finishedSessions.first { $0.sourceRoutineID == routine.id }?.startedAt
    }
}

// MARK: - Active workout card

struct ActiveWorkoutCard: View {
    @Bindable var session: Session
    @Bindable var restTimer: RestTimerEngine
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ChalkPanel {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                let stats = WorkoutStats.compute(for: session, now: context.date)
                VStack(alignment: .leading, spacing: Chalk.Space.md) {
                    HStack {
                        Label("In progress", systemImage: "circle.fill")
                            .labelStyle(.titleAndIcon)
                            .chalkLabelStyle(color: .chalkAccentOnPanel)
                        Spacer()
                        Text("Started \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.chalkFootnote)
                            .foregroundStyle(.chalkOnPanel2)
                    }
                    Text(session.routineSnapshotName.isEmpty ? "Workout" : session.routineSnapshotName)
                        .font(.chalkDisplay)
                        .textCase(.uppercase)
                        .foregroundStyle(.chalkOnPanel)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: Chalk.Space.md) {
                        ChalkMetric("Elapsed", value: ChalkFormat.clock(seconds: stats.durationSeconds), onPanel: true)
                        ChalkMetric("Sets", value: "\(stats.completedSets)/\(stats.plannedSets)", onPanel: true)
                        if restTimer.isRunning && restTimer.sessionID == session.id {
                            ChalkMetric(
                                "Rest",
                                value: RestTimerText.clock(restTimer.remaining),
                                onPanel: true,
                                valueColor: .chalkAccentOnPanel
                            )
                        }
                    }
                    ChalkProgressBar(
                        progress: stats.plannedSets > 0 ? Double(stats.completedSets) / Double(stats.plannedSets) : 0
                    )
                    Button("Resume workout", action: onResume)
                        .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
                        .accessibilityIdentifier("today.resume")
                    Button("Discard workout", action: onDiscard)
                        .buttonStyle(.chalk(.onPanel, size: .compact, fullWidth: true))
                        .accessibilityIdentifier("today.discard")
                }
            }
        }
    }
}

// MARK: - Routine summary text

enum RoutineSummary {
    /// "4 exercises · 14 sets · last done Tue, Sep 30" / "… · not done yet".
    static func line(for routine: Routine, lastDone: Date?) -> String {
        let exercises = routine.exercises ?? []
        let sets = exercises.reduce(0) { $0 + $1.targetSets }
        var parts = ["\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")", "\(sets) sets"]
        if let lastDone {
            parts.append("last done \(lastDone.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
        } else {
            parts.append("not done yet")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("Today — demo history") {
    TodayView()
        .environment(AppRouter())
        .environment(RestTimerEngine(scheduler: NoopNotificationScheduler()))
        .modelContainer(PreviewModelContainer.makeDemo())
}

#Preview("Today — first launch") {
    TodayView()
        .environment(AppRouter())
        .environment(RestTimerEngine(scheduler: NoopNotificationScheduler()))
        .modelContainer(PreviewModelContainer.make())
}
