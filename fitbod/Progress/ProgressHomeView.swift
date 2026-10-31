//
//  ProgressHomeView.swift
//  fitbod
//
//  Wave-5 plan 06-08 — Progress tab root view. Three sections (Recent /
//  Trends / Compare) that aggregate all Wave 2 destinations:
//  ExerciseProgressView (PROG-01) + WeeklyTonnageView (PROG-04) +
//  ExercisePRsView (PROG-05) + SessionComparisonView (PROG-07).
//
//  ## Section composition (UI-SPEC § ProgressHomeView lines 130–154)
//
//  Section 1 — Recent: per-exercise cards sorted by most-recently-trained;
//  tap pushes ExerciseProgressView(exercise:).
//
//  Section 2 — Trends: "Weekly Tonnage" row + "Personal Records" row.
//
//  Section 3 — Compare: "This week vs last week" row anchored on the
//  latest workout that counts as a session; locked until two count.
//
//  ## Navigation routes
//
//  Two enums route into the Wave 2 surfaces:
//    ExerciseRoute: .progress(Exercise) → ExerciseProgressView
//                   .prs(Exercise)      → ExercisePRsView(.forExercise(...))
//    ProgressRoute: .weeklyTonnage       → WeeklyTonnageView
//                   .allPRs              → ExercisePRsView(.allExercises)
//                   .sessionComparison(Session) → SessionComparisonView
//
//  ## NavigationStack ownership
//
//  RESEARCH § State of the Art — each tab owns its own NavigationStack.
//  This view declares one internally with `path: $path` bound to the
//  RootView-owned NavigationPath (so re-tap on the Progress tab clears it).
//
//  ## BRU Reskin (Phase 6.1 Plan 01)
//
//  Rebuilt to BRU brutalist design system: BRUHeaderBar replaces .navigationTitle,
//  BRUSectionHead + BRUDivider rows replace List/Form, BRU type roles replace
//  system fonts. No List, Form, .listStyle, .navigationTitle, .toolbar,
//  Color.accentColor, Color(.system*), Image(systemName:), or .buttonStyle(.bordered).
//
//  [CITED: CONTEXT D-01/D-03 + UI-SPEC § Progress tab and ProgressHomeView
//   copy table + PATTERNS adjudication #3 + 06-UI-SPEC.md §Design Pivot]
//

import SwiftData
import SwiftUI

// MARK: - Navigation routes

public enum ExerciseProgressRoute: Hashable, Sendable {
    case progress(UUID)
    case prs(UUID)
}

public enum ProgressHomeRoute: Hashable, Sendable {
    case weeklyTonnage
    case allPRs
    case sessionComparison(UUID)
}

// MARK: - ProgressHomeView

public struct ProgressHomeView: View {
    @Binding public var path: NavigationPath
    @Environment(\.modelContext) private var ctx
    @Environment(\.weightUnit) private var weightUnit
    @Query private var recentSessionExercises: [SessionExercise]
    @Query private var completedSessions: [Session]
    @Query private var allExercises: [Exercise]
    /// The finished workouts that are empty (decision 6), and the finished
    /// workouts they were worked out for. Reading them means reading every
    /// set, so they are filled when the finished workouts change, never per
    /// render. Until then Recent counts every finished workout.
    @State private var emptyWorkoutIDs: Set<PersistentIdentifier> = []
    @State private var emptyWorkoutsKey: [PersistentIdentifier]?

    public init(path: Binding<NavigationPath>) {
        self._path = path
        // Recent SessionExercise rows ordered by their parent session's
        // startedAt desc — the inner sort is in Swift since SwiftData
        // @Query sort doesn't traverse optional relationships well in
        // iOS 18 (Pitfall 1).
        _recentSessionExercises = Query(sort: [SortDescriptor(\SessionExercise.orderIndex, order: .forward)])
        _completedSessions = Query(
            filter: #Predicate<Session> { $0.completedAt != nil },
            sort: \Session.startedAt,
            order: .reverse
        )
        _allExercises = Query()
    }

    public var body: some View {
        // Read the finished workouts before the pass over logged rows. The
        // pass reads each row's workout and, run before this query, costs
        // ~12 ms more per body with a year and a half of logs.
        let finishedIDs = completedSessions.map(\.persistentModelID)
        // One pass over the logged rows feeds both Recent and Trends.
        let stats = recentStats
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                Color.bruPaper.ignoresSafeArea()

                VStack(spacing: 0) {
                    BRUHeaderBar(center: "Progress")

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            historySection
                            recentSection(stats)
                            trendsSection(stats)
                            compareSection
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ExerciseProgressRoute.self) { route in
                routeDestination(route)
            }
            .navigationDestination(for: ProgressHomeRoute.self) { route in
                routeDestination(route)
            }
            .placeholderPRsDestination()
            .sessionHistoryDestinations()
        }
        .task(id: finishedIDs) {
            guard emptyWorkoutsKey != finishedIDs else { return }
            emptyWorkoutIDs = SessionSetActions.emptyWorkoutIDs(
                among: completedSessions,
                known: emptyWorkoutsKey.map { (finished: $0, empty: emptyWorkoutIDs) },
                in: ctx
            )
            emptyWorkoutsKey = finishedIDs
        }
    }

    // MARK: - Sections

    /// History — every finished workout, newest first.
    @ViewBuilder
    private var historySection: some View {
        BRUSectionHead("History")
        progressRow(
            title: "Workouts",
            subtitle: historySubLabel,
            identifier: "progress.history"
        ) {
            path.append(SessionHistoryRoute.list)
        }
        BRUDivider(.ink)
    }

    /// Recent — top 10 most-recently-trained exercises with session count
    /// + last-logged relative date. Tap pushes ExerciseProgressView. Only
    /// workouts that count as sessions train an exercise.
    @ViewBuilder
    private func recentSection(_ stats: [UUID: RecentStat]) -> some View {
        // Read once per render; each read sorts every logged exercise row.
        let recent = recentExercisesCondensed

        BRUSectionHead("Recent")

        if recent.isEmpty {
            bruEmptyState(
                heading: "No history yet",
                body: "Log a session to start seeing your progress."
            )
        } else {
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, exercise in
                progressRow(title: exercise.name, subtitle: recentSubLabel(stats[exercise.id])) {
                    path.append(ExerciseProgressRoute.progress(exercise.id))
                }

                if index < recent.count - 1 {
                    BRUDivider(.hair)
                }
            }
        }

        BRUDivider(.ink)
    }

    /// Trends — Weekly Tonnage + Personal Records rows. Always renders.
    @ViewBuilder
    private func trendsSection(_ stats: [UUID: RecentStat]) -> some View {
        BRUSectionHead("Trends")

        progressRow(title: "Weekly Tonnage", subtitle: weeklyTonnageSubLabel) {
            path.append(ProgressHomeRoute.weeklyTonnage)
        }

        BRUDivider(.hair)

        progressRow(title: "Personal Records", subtitle: allPRsSubLabel(trained: stats.count)) {
            path.append(ProgressHomeRoute.allPRs)
        }

        BRUDivider(.ink)
    }

    /// Compare — single "This week vs last week" row anchored on the
    /// latest workout that counts as a session. Empty state until two
    /// count, since an empty workout is never compared (decision 6).
    @ViewBuilder
    private var compareSection: some View {
        BRUSectionHead("Compare")

        let latest = latestCountedWorkouts
        if latest.count == 2, let anchor = latest.first {
            progressRow(title: "This week vs last week", subtitle: compareSubLabel) {
                path.append(ProgressHomeRoute.sessionComparison(anchor.id))
            }
        } else {
            bruEmptyState(
                heading: "No comparable session yet",
                body: "Log a routine twice to compare."
            )
        }

        BRUDivider(.ink)
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func routeDestination(_ route: ExerciseProgressRoute) -> some View {
        switch route {
        case .progress(let id):
            if let ex = allExercises.first(where: { $0.id == id }) {
                ExerciseProgressView(exercise: ex)
            } else {
                Text("Exercise not found")
            }
        case .prs(let id):
            ExercisePRsView(scope: .forExercise(id))
        }
    }

    @ViewBuilder
    private func routeDestination(_ route: ProgressHomeRoute) -> some View {
        switch route {
        case .weeklyTonnage:
            WeeklyTonnageView()
        case .allPRs:
            ExercisePRsView(scope: .allExercises)
        case .sessionComparison(let id):
            if let session = completedSessions.first(where: { $0.id == id }) {
                SessionComparisonView(anchorSession: session)
            } else {
                Text("Session not found")
            }
        }
    }

    // MARK: - Row

    /// One drill-down row: title, muted sub-line, and a "›" that VoiceOver skips.
    private func progressRow(
        title: String,
        subtitle: String,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    Text(subtitle)
                        .font(BRUFont.labelSmall)
                        .foregroundStyle(Color.bruMuted)
                }
                Spacer()
                Text("›")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }

    // MARK: - BRU empty state

    @ViewBuilder
    private func bruEmptyState(heading: String, body: String) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text(heading)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruMuted)
            Text(body)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    /// A finished workout not known to be empty. A lookup in the cached
    /// empty workouts, never a read of the workout's sets.
    private func countsAsSession(_ session: Session) -> Bool {
        guard session.completedAt != nil else { return false }
        return emptyWorkoutIDs.isEmpty || !emptyWorkoutIDs.contains(session.persistentModelID)
    }

    /// The latest two workouts that count as sessions, newest first, by the
    /// shared rule. It stops at the second, so it reads only the newest
    /// workouts' sets.
    private var latestCountedWorkouts: [Session] {
        var latest: [Session] = []
        for workout in SessionSetActions.countedWorkouts(completedSessions) {
            latest.append(workout)
            if latest.count == 2 { break }
        }
        return latest
    }

    /// Top-10 most-recently-trained Exercise rows from workouts that count
    /// as sessions. Dedupes by exercise.id keeping the most-recent
    /// SessionExercise.
    private var recentExercisesCondensed: [Exercise] {
        // Sort SessionExercise rows by parent session's startedAt desc.
        let sorted = recentSessionExercises
            .compactMap { se -> (SessionExercise, Date)? in
                guard let session = se.session,
                      countsAsSession(session) else { return nil }
                return (se, session.startedAt)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        // Dedupe by exercise.id keeping first (most recent).
        var seen: Set<UUID> = []
        var result: [Exercise] = []
        for se in sorted {
            guard let ex = se.exercise else { continue }
            if !seen.contains(ex.id) {
                seen.insert(ex.id)
                result.append(ex)
                if result.count >= 10 { break }
            }
        }
        return result
    }

    /// Per exercise: how many logged rows from workouts that count as
    /// sessions it has, and the latest of their workout start dates. One
    /// pass over the rows.
    private struct RecentStat {
        var count = 0
        var lastDate: Date?
    }

    private var recentStats: [UUID: RecentStat] {
        var stats: [UUID: RecentStat] = [:]
        for se in recentSessionExercises {
            guard let id = se.exercise?.id,
                  let session = se.session,
                  countsAsSession(session) else { continue }
            var stat = stats[id] ?? RecentStat()
            stat.count += 1
            stat.lastDate = max(stat.lastDate ?? session.startedAt, session.startedAt)
            stats[id] = stat
        }
        return stats
    }

    private func recentSubLabel(_ stat: RecentStat?) -> String {
        let sessions = BRUCountLabel.text(stat?.count ?? 0, "session")
        guard let lastDate = stat?.lastDate else {
            return sessions
        }
        let rel = lastDate.formatted(.relative(presentation: .named))
        return "\(sessions) · last logged \(rel)"
    }

    private var weeklyTonnageSubLabel: String {
        // Compute this-week tonnage from completedSessions via SetEntries
        // inline — heavy precision is not required for a sub-label.
        let now = Date.now
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start else {
            return "View your weekly volume."
        }
        var total: Double = 0
        for session in completedSessions where session.startedAt >= weekStart {
            for se in (session.exercises ?? []) {
                for set in (se.sets ?? []) where set.isComplete && !set.isWarmup {
                    total += set.weight * Double(set.reps)
                }
            }
        }
        if total <= 0 {
            return "Log a workout to see this week's tonnage."
        }
        return "\(Int(total.rounded()).formatted()) \(weightUnit.rawValue) this week"
    }

    private var historySubLabel: String {
        guard let last = completedSessions.first else {
            return "Finish a workout to see it here."
        }
        let count = completedSessions.count
        let finished = count == 1 ? "1 finished" : "\(count) finished"
        return "\(finished) · last \(last.startedAt.formatted(.relative(presentation: .named)))"
    }

    /// Counts exercises with finished work, not the whole catalog: one per
    /// key of `recentStats`.
    private func allPRsSubLabel(trained: Int) -> String {
        switch trained {
        case 0:  return "Finish a workout to set your first records."
        case 1:  return "Records for 1 exercise"
        default: return "Records for \(trained) exercises"
        }
    }

    private var compareSubLabel: String {
        "Compare to a routine you've logged twice."
    }
}
