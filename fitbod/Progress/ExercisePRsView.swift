//
//  ExercisePRsView.swift
//  fitbod
//
//  Wave-4 plan 06-07 — per-exercise / all-exercises PR list (CONTEXT
//  D-10..D-13 + REQUIREMENTS PROG-05).
//
//  ## Scope (CONTEXT D-13)
//
//    .forExercise(UUID) — single exercise PR detail
//    .allExercises      — all-exercises feed (consumed by
//                         ProgressHomeView's "Personal Records" row)
//
//  ## Layout
//
//  Header: segmented `Picker` over `IntentFilter` (.strength /
//          .hypertrophy / .all)
//  Body:   List with 4 Section blocks (Weight / Reps / Volume / e1RM)
//          each rendering up to 3 sub-sections per rep bucket
//          (1–6 reps / 7–10 reps / 11+ reps). The e1RM section
//          omits the 11+ bucket and replaces it with the verbatim
//          string "Suppressed for reps above 10." (PROG-02 + D-04).
//
//  ## Top 3 PRs per (kind, bucket)
//
//  PRDetector.PRTable holds ONE PRRecord per slot (the current best).
//  This view needs the top-3 history, so it does its own post-fetch
//  sort over the @Query<SetEntry> result by the kind's PR criterion.
//  Acceptable at v1 single-user scale per CONTEXT D-12 ("computed
//  on-demand from SetEntry history; NOT denormalized").
//
//  ## Empty state (UI-SPEC verbatim)
//
//    Heading: "No PRs yet"
//    Body:    "Complete a working set to set your first record."
//
//  ## Outer/inner @Query split (PATTERNS §Pattern D)
//
//  Outer view owns the IntentFilter @State + scope param. Inner
//  `PRsHost` declares `@Query<SetEntry>` predicate-narrowed to the
//  scope (UUID local-let capture per Pitfall 3) and computes the
//  display rows inline.
//
//  ## Row tap → session destination
//
//  No `CompletedSessionView` exists in v1. PR row taps push a
//  placeholder `Text("Session of {date}")` per the plan; documented
//  as a v2 follow-up entry point.
//
//  [CITED: CONTEXT D-10..D-13 + UI-SPEC § ExercisePRsView + PROG-05]
//

import SwiftData
import SwiftUI

// MARK: - Scope + IntentFilter

public enum ExercisePRsViewScope: Hashable, Sendable {
    case forExercise(UUID)
    case allExercises
}

public enum ExercisePRsIntentFilter: String, CaseIterable, Sendable {
    case strength
    case hypertrophy
    case all

    public var label: String {
        switch self {
        case .strength:    return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .all:         return "All"
        }
    }

    public func matches(intent: Intent) -> Bool {
        switch self {
        case .strength:    return intent == .strength
        case .hypertrophy: return intent == .hypertrophy
        case .all:         return true
        }
    }
}

// MARK: - ExercisePRsView (outer)

public struct ExercisePRsView: View {
    public let scope: ExercisePRsViewScope
    @State private var intentFilter: ExercisePRsIntentFilter = .all

    public init(scope: ExercisePRsViewScope) {
        self.scope = scope
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Intent", selection: $intentFilter) {
                ForEach(ExercisePRsIntentFilter.allCases, id: \.self) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            PRsHost(scope: scope, intentFilter: intentFilter)
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var navTitle: String {
        switch scope {
        case .forExercise: return "Personal Records"
        case .allExercises: return "Personal Records"
        }
    }
}

// MARK: - PRsHost (inner @Query host)

private struct PRsHost: View {
    @Query private var sets: [SetEntry]
    let scope: ExercisePRsViewScope
    let intentFilter: ExercisePRsIntentFilter

    init(scope: ExercisePRsViewScope, intentFilter: ExercisePRsIntentFilter) {
        self.scope = scope
        self.intentFilter = intentFilter
        switch scope {
        case .forExercise(let exerciseID):
            let targetID = exerciseID
            _sets = Query(
                filter: #Predicate<SetEntry> { entry in
                    entry.isComplete
                        && !entry.isWarmup
                        && entry.sessionExercise?.exercise?.id == targetID
                },
                sort: \SetEntry.completedAt,
                order: .reverse
            )
        case .allExercises:
            _sets = Query(
                filter: #Predicate<SetEntry> { entry in
                    entry.isComplete && !entry.isWarmup
                },
                sort: \SetEntry.completedAt,
                order: .reverse
            )
        }
    }

    var body: some View {
        let filtered = sets.filter { entry in
            guard let session = entry.sessionExercise?.session else { return false }
            let intent = Intent(rawValue: session.intentRaw) ?? .strength
            return intentFilter.matches(intent: intent)
        }
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    section(kind: .weight, label: "Weight", sets: filtered)
                    section(kind: .reps, label: "Reps", sets: filtered)
                    section(kind: .volume, label: "Volume", sets: filtered)
                    section(kind: .e1RM, label: "e1RM", sets: filtered)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("No PRs yet")
                .font(.headline)
            Text("Complete a working set to set your first record.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func section(kind: PRKind, label: String, sets: [SetEntry]) -> some View {
        Section(header: Text(label)) {
            ForEach(bucketsToRender(kind: kind), id: \.rawValue) { bucket in
                bucketBlock(kind: kind, bucket: bucket, sets: sets)
            }
            if kind == .e1RM {
                Text("Suppressed for reps above 10.")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    private func bucketsToRender(kind: PRKind) -> [RepBucket] {
        if kind == .e1RM {
            return [.strength, .hypertrophy]   // omit .highRep per D-04
        }
        return RepBucket.allCases
    }

    @ViewBuilder
    private func bucketBlock(kind: PRKind, bucket: RepBucket, sets: [SetEntry]) -> some View {
        let bucketSets = sets.filter { RepBucket.bucket(for: $0.reps) == bucket }
        let topThree = topThree(kind: kind, sets: bucketSets)
        if !topThree.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(bucketLabel(bucket: bucket))
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                ForEach(Array(topThree.enumerated()), id: \.offset) { _, entry in
                    NavigationLink(
                        value: PRsRouteDestination.session(date: entry.completedAt, setEntryID: entry.id)
                    ) {
                        HStack {
                            Text(rowText(kind: kind, set: entry))
                                .font(.body)
                            Spacer()
                            Text(entry.completedAt.formatted(.dateTime.month().day().year()))
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func bucketLabel(bucket: RepBucket) -> String {
        switch bucket {
        case .strength:    return "1–6 reps"      // en-dash
        case .hypertrophy: return "7–10 reps"     // en-dash
        case .highRep:     return "11+ reps"
        }
    }

    private func topThree(kind: PRKind, sets: [SetEntry]) -> [SetEntry] {
        let sorted: [SetEntry]
        switch kind {
        case .weight:
            sorted = sets.sorted { $0.weight > $1.weight }
        case .reps:
            sorted = sets.sorted { $0.reps > $1.reps }
        case .volume:
            sorted = sets.sorted { ($0.weight * Double($0.reps)) > ($1.weight * Double($1.reps)) }
        case .e1RM:
            // Score sets by e1RM; suppress nil (reps > 10) from the sort.
            let scored = sets.compactMap { entry -> (entry: SetEntry, score: Double)? in
                guard let score = OneRepMax.estimate(weight: entry.weight, reps: entry.reps) else { return nil }
                return (entry, score)
            }
            sorted = scored.sorted { $0.score > $1.score }.map(\.entry)
        }
        return Array(sorted.prefix(3))
    }

    private func rowText(kind: PRKind, set: SetEntry) -> String {
        let weightStr = formatWeight(set.weight)
        let rpeStr = set.rpe.map { String(format: "%g", $0) } ?? "—"
        switch kind {
        case .weight:
            return "\(weightStr) kg × \(set.reps) @ RPE \(rpeStr)"
        case .reps:
            return "\(set.reps) reps @ \(weightStr) kg, RPE \(rpeStr)"
        case .volume:
            let tonnage = Int((set.weight * Double(set.reps)).rounded())
            return "\(tonnage) kg single-set (\(weightStr) × \(set.reps))"
        case .e1RM:
            let e1rm = OneRepMax.estimate(weight: set.weight, reps: set.reps).map { Int($0.rounded()) } ?? 0
            return "\(e1rm) kg e1RM (\(weightStr) × \(set.reps))"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}

// MARK: - Placeholder destination for PR row tap

/// Placeholder destination type used by `ExercisePRsView` row taps.
/// v1 has no `CompletedSessionView` — the row pushes a stub `Text`
/// destination. Documented as a v2 follow-up entry point.
public enum PRsRouteDestination: Hashable, Sendable {
    case session(date: Date, setEntryID: UUID)
}

public extension View {
    /// Wires the v1 placeholder destination for ExercisePRsView row taps.
    /// Consumer views (ExercisePRsView, ProgressHomeView) attach this so
    /// the NavigationLink(value: PRsRouteDestination.session(...)) inside
    /// PR rows lands on a readable stub instead of failing silently.
    @ViewBuilder
    func placeholderPRsDestination() -> some View {
        self.navigationDestination(for: PRsRouteDestination.self) { dest in
            switch dest {
            case .session(let date, _):
                Text("Session of \(date.formatted(.dateTime.month().day().year()))")
                    .navigationTitle("Session")
            }
        }
    }
}
