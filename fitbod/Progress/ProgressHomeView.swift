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
//  most recent completed session.
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
//  [CITED: CONTEXT D-01/D-03 + UI-SPEC § Progress tab and ProgressHomeView
//   copy table + PATTERNS adjudication #3]
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
    @Query private var recentSessionExercises: [SessionExercise]
    @Query private var completedSessions: [Session]
    @Query private var allExercises: [Exercise]

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
        NavigationStack(path: $path) {
            List {
                recentSection
                trendsSection
                compareSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Progress")
            .navigationDestination(for: ExerciseProgressRoute.self) { route in
                routeDestination(route)
            }
            .navigationDestination(for: ProgressHomeRoute.self) { route in
                routeDestination(route)
            }
            .placeholderPRsDestination()
        }
    }

    // MARK: - Sections

    /// Recent — top 10 most-recently-trained exercises with session count
    /// + last-logged relative date. Tap pushes ExerciseProgressView.
    @ViewBuilder
    private var recentSection: some View {
        Section {
            if recentExercisesCondensed.isEmpty {
                emptyRow(
                    heading: "No history yet",
                    body: "Log a session to start seeing your progress."
                )
            } else {
                ForEach(recentExercisesCondensed, id: \.id) { exercise in
                    NavigationLink(value: ExerciseProgressRoute.progress(exercise.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.body)
                            Text(recentSubLabel(for: exercise))
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
            }
        } header: {
            Text("Recent")
        }
    }

    /// Trends — Weekly Tonnage + Personal Records rows. Always renders.
    @ViewBuilder
    private var trendsSection: some View {
        Section {
            NavigationLink(value: ProgressHomeRoute.weeklyTonnage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Tonnage")
                        .font(.body)
                    Text(weeklyTonnageSubLabel)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            NavigationLink(value: ProgressHomeRoute.allPRs) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Records")
                        .font(.body)
                    Text(allPRsSubLabel)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        } header: {
            Text("Trends")
        }
    }

    /// Compare — single "This week vs last week" row anchored on the
    /// most recent completed session. Empty state when no completed
    /// sessions exist.
    @ViewBuilder
    private var compareSection: some View {
        Section {
            if let anchor = completedSessions.first {
                NavigationLink(value: ProgressHomeRoute.sessionComparison(anchor.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This week vs last week")
                            .font(.body)
                        Text("Compare to a routine you've logged twice.")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            } else {
                emptyRow(
                    heading: "No comparable session yet",
                    body: "Log a routine twice to compare."
                )
            }
        } header: {
            Text("Compare")
        }
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

    // MARK: - Helpers

    @ViewBuilder
    private func emptyRow(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.body)
                .foregroundStyle(Color(.secondaryLabel))
            Text(body)
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }

    /// Top-10 most-recently-trained Exercise rows. Dedupes by
    /// exercise.id keeping the most-recent SessionExercise.
    private var recentExercisesCondensed: [Exercise] {
        // Sort SessionExercise rows by parent session's startedAt desc.
        let sorted = recentSessionExercises
            .compactMap { se -> (SessionExercise, Date)? in
                guard let started = se.session?.startedAt,
                      se.session?.completedAt != nil else { return nil }
                return (se, started)
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

    private func recentSubLabel(for exercise: Exercise) -> String {
        let sessionsForEx = recentSessionExercises.filter {
            $0.exercise?.id == exercise.id && $0.session?.completedAt != nil
        }
        let count = sessionsForEx.count
        guard let lastDate = sessionsForEx.compactMap(\.session?.startedAt).max() else {
            return "\(count) sessions"
        }
        let rel = lastDate.formatted(.relative(presentation: .named))
        return "\(count) sessions · last logged \(rel)"
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
        return "\(Int(total.rounded())) kg this week"
    }

    private var allPRsSubLabel: String {
        let exerciseCount = allExercises.count
        return "Browse PRs across \(exerciseCount) exercises"
    }
}
