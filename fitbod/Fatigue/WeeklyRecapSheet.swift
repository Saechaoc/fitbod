//
//  WeeklyRecapSheet.swift
//  fitbod
//
//  Phase 5 VOL-07 — full-screen sheet auto-presented on first app
//  open of a new calendar week. Per CONTEXT Claude's Discretion the
//  sheet has 4 sections (Sessions / Muscles Hit / Under-Trained /
//  Progress); per UI-SPEC §Copywriting Contract every label is
//  verbatim.
//
//  Trigger guard logic lives in `WeeklyRecapTrigger.evaluate(...)` —
//  a pure-function helper testable without UI. RootView's TodayView
//  reads the decision in `.task` and either sets
//  `presentingWeeklyRecap = true` (presents this sheet) and/or marks
//  `UserSettings.weeklyRecapShownForWeekStart = thisMonday` per
//  Pitfalls #7 + #8.
//

import SwiftData
import SwiftUI

/// Pure-function trigger guard per RESEARCH §12.1 + Pitfalls #7 / #8.
/// Caller injects all dependencies — testable without a UI fixture.
public enum WeeklyRecapTrigger {

    public struct Decision: Sendable, Equatable {
        public let shouldPresent: Bool
        public let shouldMarkSeen: Bool

        public init(shouldPresent: Bool, shouldMarkSeen: Bool) {
            self.shouldPresent = shouldPresent
            self.shouldMarkSeen = shouldMarkSeen
        }
    }

    /// Decide whether to present the recap sheet (and whether to mark
    /// the current week's seen-flag regardless of presentation).
    ///
    /// - Parameter thisMonday: Monday-anchored midnight of the current week.
    /// - Parameter lastShown: Whatever date is stored on
    ///   `UserSettings.weeklyRecapShownForWeekStart`. nil on cold install.
    /// - Parameter hasSessionsLastWeek: Caller-precomputed boolean —
    ///   true iff ≥ 1 completed Session exists in [thisMonday - 7d,
    ///   thisMonday). Avoids passing a ModelContext into a pure-fn
    ///   helper.
    /// - Parameter calendar: Defaults to `.current`. Tests inject a
    ///   deterministic Calendar for Pitfall #7 coverage.
    public static func evaluate(
        thisMonday: Date,
        lastShown: Date?,
        hasSessionsLastWeek: Bool,
        calendar: Calendar = .current
    ) -> Decision {
        // Pitfall #7: compare via Calendar.isDate(_:equalTo:toGranularity: .day)
        // so DST + timezone edges don't false-trigger.
        if let lastShown = lastShown,
           calendar.isDate(lastShown, equalTo: thisMonday, toGranularity: .day) {
            return Decision(shouldPresent: false, shouldMarkSeen: false)
        }
        // Pitfall #8: zero sessions last week → don't show the recap
        // retroactively, but mark seen so a stale `nil` lastShown
        // doesn't trigger a sheet two weeks from now when the user
        // logs something.
        if !hasSessionsLastWeek {
            return Decision(shouldPresent: false, shouldMarkSeen: true)
        }
        return Decision(shouldPresent: true, shouldMarkSeen: true)
    }
}

public struct WeeklyRecapSheet: View {
    /// The START of the new week — the Monday on which this sheet
    /// presents. Content shows the PRIOR week.
    public let weekStart: Date

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @Query private var allMuscles: [MuscleGroup]
    @Query private var allTargets: [MuscleVolumeTarget]

    public init(weekStart: Date) {
        self.weekStart = weekStart
    }

    private var priorWeekStart: Date {
        weekStart.addingTimeInterval(-7 * 86_400)
    }

    private var settings: UserSettings? { settingsList.first }

    public var body: some View {
        NavigationStack {
            List {
                sessionsSection
                musclesHitSection
                underTrainedSection
                progressSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Weekly Recap")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    @ViewBuilder
    private var sessionsSection: some View {
        let count = lastWeekSessionsCount()
        let routineCount = lastWeekRoutinesCount()
        let sessionWord = count == 1 ? "session" : "sessions"
        let routineWord = routineCount == 1 ? "routine" : "routines"

        Section("Sessions") {
            Text("Last week you logged \(count) \(sessionWord).")
                .font(.body)
            if routineCount > 1 {
                Text("Across \(routineCount) \(routineWord).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var musclesHitSection: some View {
        let minSets = settings?.frequencyHitMinSets ?? 2
        let hits = musclesHitLastWeek(minSets: minSets)

        Section("Muscles Hit") {
            if hits.isEmpty {
                Text("No muscles met the frequency threshold last week.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hits, id: \.slug) { row in
                    HStack {
                        Text(row.displayName)
                        Spacer()
                        Text("\(row.count) \(row.count == 1 ? "session" : "sessions")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var underTrainedSection: some View {
        let underTrained = musclesUnderTrainedLastWeek()

        Section("Under-Trained") {
            if underTrained.isEmpty {
                Text("All trained muscles reached MEV last week.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(underTrained, id: \.slug) { row in
                    HStack {
                        Text(row.displayName)
                        Spacer()
                        Text("below MEV — \(row.totalSets) / \(row.mev) sets")
                            .font(.caption)
                            .foregroundStyle(Color("VolumeBelowMEVGray"))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        let progress = topExercisesProgress()

        Section {
            if progress.isEmpty {
                Text("Not enough data to compute e1RM movement.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(progress, id: \.exerciseID) { row in
                    HStack {
                        Text(row.exerciseName.capitalized)
                        Spacer()
                        Text(row.deltaCopy)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(row.deltaColor)
                    }
                }
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("Top 5 exercises by working-set count last week. e1RM vs same exercise week prior.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data computations

    @MainActor
    private func lastWeekSessionsCount() -> Int {
        let start = priorWeekStart
        let end = weekStart
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        return (try? ctx.fetchCount(descriptor)) ?? 0
    }

    @MainActor
    private func lastWeekRoutinesCount() -> Int {
        let start = priorWeekStart
        let end = weekStart
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> {
                $0.startedAt >= start && $0.startedAt < end && $0.completedAt != nil
            }
        )
        let sessions = (try? ctx.fetch(descriptor)) ?? []
        return Set(sessions.map { $0.routineSnapshotName }).count
    }

    @MainActor
    private func musclesHitLastWeek(minSets: Int) -> [MuscleRow] {
        allMuscles.compactMap { muscle in
            let count = FatigueModel.frequencyHits(
                muscleSlug: muscle.slug,
                weekStart: priorWeekStart,
                minContribution: Double(minSets),
                in: ctx
            )
            guard count > 0 else { return nil }
            return MuscleRow(slug: muscle.slug, displayName: muscle.displayName, count: count)
        }
        .sorted { $0.count > $1.count }
    }

    @MainActor
    private func musclesUnderTrainedLastWeek() -> [UnderTrainedRow] {
        allMuscles.compactMap { muscle in
            guard let target = allTargets.first(where: { $0.muscle?.slug == muscle.slug }) else { return nil }
            let total = FatigueModel.weeklyVolume(
                muscleSlug: muscle.slug,
                weekStart: priorWeekStart,
                in: ctx
            )
            let rounded = total.totalSetsRounded
            guard rounded > 0 && rounded < target.mev else { return nil }
            return UnderTrainedRow(
                slug: muscle.slug,
                displayName: muscle.displayName,
                totalSets: rounded,
                mev: target.mev
            )
        }
    }

    @MainActor
    private func topExercisesProgress() -> [ProgressRow] {
        let start = priorWeekStart
        let end = weekStart
        let priorStart = priorWeekStart.addingTimeInterval(-7 * 86_400)
        let workingKinds: Set<String> = ["working", "drop", "failure", "rest_pause"]

        // 1. Fetch all working SetEntries in prior week — Pitfall #1
        //    simple predicate gates + Swift post-filter for multi-hop.
        let lastWeekDescriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete == true && entry.isWarmup == false
            }
        )
        let allCompleted = (try? ctx.fetch(lastWeekDescriptor)) ?? []
        let lastWeekEntries = allCompleted.filter { entry in
            guard workingKinds.contains(entry.setTypeRaw) else { return false }
            guard let started = entry.sessionExercise?.session?.startedAt else { return false }
            return started >= start && started < end
        }
        let priorWeekEntries = allCompleted.filter { entry in
            guard workingKinds.contains(entry.setTypeRaw) else { return false }
            guard let started = entry.sessionExercise?.session?.startedAt else { return false }
            return started >= priorStart && started < start
        }

        // 2. Group last week's entries by exercise; count working sets.
        var setCountByExercise: [UUID: (exercise: Exercise, count: Int)] = [:]
        for entry in lastWeekEntries {
            guard let exercise = entry.sessionExercise?.exercise else { continue }
            var existing = setCountByExercise[exercise.id] ?? (exercise: exercise, count: 0)
            existing.count += 1
            setCountByExercise[exercise.id] = existing
        }
        let top5 = setCountByExercise.values.sorted { $0.count > $1.count }.prefix(5)

        // 3. For each top exercise, compute last/prior week top-set e1RM.
        let units = settings?.unitsRaw ?? "lb"
        let unitLabel = units == "kg" ? "kg" : "lb"

        return top5.compactMap { entry in
            let lastWeekE1RM = topSetE1RM(in: lastWeekEntries, exerciseID: entry.exercise.id)
            let priorWeekE1RM = topSetE1RM(in: priorWeekEntries, exerciseID: entry.exercise.id)
            guard let lw = lastWeekE1RM, let pw = priorWeekE1RM else {
                return ProgressRow(
                    exerciseID: entry.exercise.id,
                    exerciseName: entry.exercise.canonicalName,
                    deltaCopy: "—",
                    deltaColor: .secondary
                )
            }
            let delta = lw - pw
            let sign = delta >= 0 ? "+" : ""
            let copy = "\(sign)\(String(format: "%.1f", delta)) \(unitLabel) e1RM"
            let color: Color
            if delta > 0.1 {
                color = Color(.systemGreen)
            } else if delta < -0.1 {
                color = Color(.systemRed)
            } else {
                color = .secondary
            }
            return ProgressRow(
                exerciseID: entry.exercise.id,
                exerciseName: entry.exercise.canonicalName,
                deltaCopy: copy,
                deltaColor: color
            )
        }
    }

    private func topSetE1RM(in entries: [SetEntry], exerciseID: UUID) -> Double? {
        var best: Double? = nil
        for entry in entries where entry.sessionExercise?.exercise?.id == exerciseID {
            if let e = OneRepMaxEstimator.estimate(weight: entry.weight, reps: entry.reps) {
                if best == nil || e > best! { best = e }
            }
        }
        return best
    }

    // MARK: - Row types

    private struct MuscleRow {
        let slug: String
        let displayName: String
        let count: Int
    }

    private struct UnderTrainedRow {
        let slug: String
        let displayName: String
        let totalSets: Int
        let mev: Int
    }

    private struct ProgressRow {
        let exerciseID: UUID
        let exerciseName: String
        let deltaCopy: String
        let deltaColor: Color
    }
}
