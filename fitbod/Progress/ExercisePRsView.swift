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
//  ## Layout (Phase 6.1 BRU reskin — 06.1-03)
//
//  BRUHeaderBar(left: back, center: nav title, right: "ALL TIME")
//  3-segment inverted-active intent toggle bar
//  BRUDivider(.ink)
//  ScrollView → LazyVStack of 4 sections (Weight / Reps / Volume / e1RM)
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
import UIKit

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
    @Environment(\.dismiss) private var dismiss

    public init(scope: ExercisePRsViewScope) {
        self.scope = scope
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹") { dismiss() },
                center: navTitle,
                right: HeaderAction("ALL TIME") { }
            )

            // 3-segment inverted-active intent toggle bar
            intentToggle

            BRUDivider(.ink)

            PRsHost(scope: scope, intentFilter: intentFilter)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - Intent Toggle

    private var intentToggle: some View {
        HStack(spacing: 0) {
            ForEach(Array(ExercisePRsIntentFilter.allCases.enumerated()), id: \.element) { index, filter in
                let isSelected = intentFilter == filter
                let isLast = index == ExercisePRsIntentFilter.allCases.count - 1

                Button {
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    intentFilter = filter
                } label: {
                    Text(filter.label.uppercased())
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.bruInk : Color.clear)
                }
                .buttonStyle(.plain)

                if !isLast {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.bruPaper)
    }

    private var navTitle: String {
        "Personal Records"
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
        // Broad predicate + Swift post-filter: a multi-level optional chain
        // (entry.sessionExercise?.exercise?.id) inside #Predicate crashes
        // SwiftData at fetch time ("Unsupported function expression").
        _sets = Query(
            filter: #Predicate<SetEntry> { entry in
                entry.isComplete && !entry.isWarmup
            },
            sort: \SetEntry.completedAt,
            order: .reverse
        )
    }

    private var scopedSets: [SetEntry] {
        switch scope {
        case .forExercise(let exerciseID):
            return sets.filter { $0.sessionExercise?.exercise?.id == exerciseID }
        case .allExercises:
            return sets
        }
    }

    var body: some View {
        let filtered = scopedSets.filter { entry in
            guard let session = entry.sessionExercise?.session else { return false }
            let intent = Intent(rawValue: session.intentRaw) ?? .strength
            return intentFilter.matches(intent: intent)
        }
        Group {
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        prSection(kind: .weight, label: "Weight", sets: filtered)
                        prSection(kind: .reps, label: "Reps", sets: filtered)
                        prSection(kind: .volume, label: "Volume", sets: filtered)
                        prSection(kind: .e1RM, label: "e1RM", sets: filtered)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No PRs yet")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Text("Complete a working set to set your first record.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Section

    @ViewBuilder
    private func prSection(kind: PRKind, label: String, sets: [SetEntry]) -> some View {
        BRUSectionHead(label)

        ForEach(bucketsToRender(kind: kind), id: \.rawValue) { bucket in
            bucketBlock(kind: kind, bucket: bucket, sets: sets)
        }

        if kind == .e1RM {
            Text("Suppressed for reps above 10.")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            BRUDivider(.ink)
        }
    }

    private func bucketsToRender(kind: PRKind) -> [RepBucket] {
        if kind == .e1RM {
            return [.strength, .hypertrophy]   // omit .highRep per D-04
        }
        return RepBucket.allCases
    }

    // MARK: - Bucket Block

    @ViewBuilder
    private func bucketBlock(kind: PRKind, bucket: RepBucket, sets: [SetEntry]) -> some View {
        let bucketSets = sets.filter { RepBucket.bucket(for: $0.reps) == bucket }
        let topThreeEntries = topThree(kind: kind, sets: bucketSets)

        if !topThreeEntries.isEmpty {
            // Bucket sub-header
            Text(bucketLabel(bucket: bucket).uppercased())
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            ForEach(Array(topThreeEntries.enumerated()), id: \.offset) { index, entry in
                NavigationLink(
                    value: PRsRouteDestination.session(date: entry.completedAt, setEntryID: entry.id)
                ) {
                    prRow(kind: kind, entry: entry)
                }
                .buttonStyle(.plain)

                if index < topThreeEntries.count - 1 {
                    BRUDivider(.hair)
                }
            }
        }
    }

    // MARK: - PR Row (3-column BRU layout per bru-screens/progress-chart.jsx)

    private func prRow(kind: PRKind, entry: SetEntry) -> some View {
        let isCurrentDay = Calendar.current.isDateInToday(entry.completedAt)
        let rowKindColor: Color = isCurrentDay ? .bruSignal : .bruInk
        let kindLabel = prKindLabel(kind: kind)
        let valueText = rowText(kind: kind, set: entry)
        let dateText = entry.completedAt.formatted(.dateTime.month().day().year()).uppercased()

        return HStack(spacing: 10) {
            // (a) Leading ~110pt fixed — kind label
            VStack(alignment: .leading, spacing: 2) {
                Text(kindLabel.uppercased())
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(rowKindColor)
            }
            .frame(width: 110, alignment: .leading)

            // (b) Center — PR value display
            BRUDisplay(valueText, size: .medium)
                .frame(maxWidth: .infinity, alignment: .center)

            // (c) Trailing — mono date
            VStack(alignment: .trailing, spacing: 2) {
                Text(dateText)
                    .font(BRUFont.labelMicro)
                    .tracking(0.5)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(isCurrentDay ? Color.bruSignal.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: - Kind Label

    private func prKindLabel(kind: PRKind) -> String {
        switch kind {
        case .weight: return "Weight PR"
        case .reps:   return "Top Reps"
        case .volume: return "Volume PR"
        case .e1RM:   return "e1RM PR"
        }
    }

    // MARK: - Bucket Label

    private func bucketLabel(bucket: RepBucket) -> String {
        switch bucket {
        case .strength:    return "1–6 reps"      // en-dash
        case .hypertrophy: return "7–10 reps"     // en-dash
        case .highRep:     return "11+ reps"
        }
    }

    // MARK: - Top 3

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

    // MARK: - Row Text

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
                VStack(spacing: 0) {
                    BRUHeaderBar(center: "Session")
                    Text("Session of \(date.formatted(.dateTime.month().day().year()))")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.bruPaper.ignoresSafeArea())
                .navigationBarHidden(true)
            }
        }
    }
}
