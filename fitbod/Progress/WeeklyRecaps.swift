//
//  WeeklyRecaps.swift
//  fitbod
//
//  RM-020: past weekly recaps. Every past week with a workout that counts
//  as a session (decision 6) has a recap, the one Today shows on its own in
//  the week after (O-4). The week list reads every week's numbers in one
//  pass over the workouts; a recap reads its own week. Both go through
//  `WeeklyRecaps.recap`, so a row and the recap it opens always agree. Both
//  read the logged sets as they are now, so a History correction changes
//  the week it touches the next time either is read.
//
//  Both read off the main actor, in a context of their own: their records
//  replay the finished workouts before the week, which on a four-year
//  history (832 workouts, 15,000 sets) is most of a second's work.
//

import Foundation
import SwiftData

/// One week's recap in numbers: its row in the week list, and its recap's
/// cover and metric grid.
struct WeekRecap: Identifiable, Equatable, Sendable {
    /// The first day of the week the recap covers, at local midnight, by
    /// the week-start setting.
    let weekStart: Date
    /// The week's workouts that count as sessions.
    let sessions: Int
    /// The training days the week's plan called for; nil with no plan
    /// (`WeeklyRecapSheet.sessionsTarget`).
    let target: Int?
    /// Working sets, each once, as Today counts its week (RM-038).
    let workingSets: Int
    let tonnage: Double
    /// The mean RPE of the working sets logged with one; nil when none was.
    let averageRPE: Double?
    /// The muscles with a volume target that the week trained below MEV, by
    /// slug, with their rounded weighted sets: the recap's Under-Trained rows.
    let underTrained: [String: Int]
    /// The records the week's workouts set, one per logged exercise and kind,
    /// as History counts a workout's records.
    let records: Int

    var id: Date { weekStart }

    var underMEV: Int { underTrained.count }

    /// The recap's cover headline, such as "A strong\nweek.".
    var headline: String {
        WeeklyRecapSheet.coverHeadline(sessions: sessions, target: target, prs: records)
    }
}

enum WeeklyRecaps {

    /// `weeks` for every workout in the store, read in a context of its own
    /// off the main actor, so it sees every saved change.
    @concurrent
    static func weeks(
        weekStartsMonday: Bool,
        now: Date = .now,
        in container: ModelContainer,
        calendar: Calendar = .current
    ) async -> [WeekRecap] {
        let context = ModelContext(container)
        return withExtendedLifetime(allLogsAndSets(in: context)) {
            weeks(
                sessions: (try? context.fetch(FetchDescriptor<Session>(
                    sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
                ))) ?? [],
                muscles: (try? context.fetch(FetchDescriptor<MuscleGroup>())) ?? [],
                targets: (try? context.fetch(FetchDescriptor<MuscleVolumeTarget>())) ?? [],
                weekStartsMonday: weekStartsMonday,
                now: now,
                in: context,
                calendar: calendar
            )
        }
    }

    /// `WeeklyRecapSheet.content`, read the same way.
    @concurrent
    static func content(
        weekStart: Date,
        minSets: Int,
        unit: WeightUnit,
        in container: ModelContainer,
        calendar: Calendar = .current
    ) async -> WeeklyRecapSheet.Content {
        let context = ModelContext(container)
        return withExtendedLifetime(allLogsAndSets(in: context)) {
            WeeklyRecapSheet.content(
                weekStart: weekStart,
                muscles: (try? context.fetch(FetchDescriptor<MuscleGroup>())) ?? [],
                targets: (try? context.fetch(FetchDescriptor<MuscleVolumeTarget>())) ?? [],
                minSets: minSets,
                unit: unit,
                in: context,
                calendar: calendar
            )
        }
    }

    /// Every logged exercise and set, in two fetches. Held while a read
    /// walks the workouts, they make the walk about four times faster than
    /// faulting each workout's in: 0.3 s against 1.4 s on a four-year
    /// history. Fetched and let go, they save nothing.
    private static func allLogsAndSets(in context: ModelContext) -> ([SessionExercise], [SetEntry]) {
        ((try? context.fetch(FetchDescriptor<SessionExercise>())) ?? [],
         (try? context.fetch(FetchDescriptor<SetEntry>())) ?? [])
    }

    /// Every past week with a workout that counts as a session, newest first:
    /// the weeks before the one `now` falls in.
    ///
    /// `sessions` is every workout, finished or not. The workouts and their
    /// sets are read once for all weeks; the working-set order, the blocks
    /// and the records are read once per call, so the number of fetches
    /// does not grow with history.
    static func weeks(
        sessions: [Session],
        muscles: [MuscleGroup],
        targets: [MuscleVolumeTarget],
        weekStartsMonday: Bool,
        now: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [WeekRecap] {
        let thisWeek = now.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday, calendar: calendar)
        var byWeek: [Date: [Session]] = [:]
        for session in sessions {
            let week = session.startedAt.mondayAtMidnightForToday(weekStartsMonday: weekStartsMonday, calendar: calendar)
            if week < thisWeek { byWeek[week, default: []].append(session) }
        }
        byWeek = byWeek.filter { !SessionSetActions.countedWorkouts($0.value).isEmpty }
        guard !byWeek.isEmpty else { return [] }

        let position = FatigueModel.workingSetPositions(in: context)
        let blocks = (try? context.fetch(FetchDescriptor<Block>())) ?? []
        let mev = mev(muscles: muscles, targets: targets)
        // History's count of each workout's records, so a row and History agree.
        let records = SessionSummary.prsBySession(sessions)
        return byWeek.keys.sorted(by: >).map { week in
            let workouts = byWeek[week] ?? []
            return recap(
                weekStart: week,
                sessions: workouts,
                sets: FatigueModel.ordered(FatigueModel.workingSets(of: workouts), by: position),
                target: WeeklyRecapSheet.sessionsTarget(
                    weekStart: FatigueModel.date(byAddingWeeks: 1, to: week, calendar: calendar),
                    blocks: blocks,
                    calendar: calendar
                ),
                mev: mev,
                records: workouts.reduce(0) { $0 + (records[$1.id]?.count ?? 0) }
            )
        }
    }

    /// One week's numbers from what it holds: every workout started in it,
    /// finished or not, and their working sets in
    /// `FatigueModel.completedWorkingSets` order, which the volume totals
    /// depend on to the last digit.
    static func recap(
        weekStart: Date,
        sessions: [Session],
        sets: [SetEntry],
        target: Int?,
        mev: [String: Int],
        records: Int
    ) -> WeekRecap {
        let rpes = sets.compactMap(\.rpe).filter { $0 > 0 }
        return WeekRecap(
            weekStart: weekStart,
            sessions: SessionSetActions.countedWorkouts(sessions).count,
            target: target,
            workingSets: FatigueModel.workingSetCount(of: sets),
            tonnage: sets.reduce(0.0) { $0 + $1.tonnage },
            averageRPE: rpes.isEmpty ? nil : rpes.reduce(0.0, +) / Double(rpes.count),
            underTrained: underTrained(FatigueModel.volumes(of: sets), mev: mev),
            records: records
        )
    }

    /// MEV by muscle slug for the muscles in `muscles` that have a volume
    /// target, each from its first target in `targets`, as the recap has
    /// always read it.
    static func mev(muscles: [MuscleGroup], targets: [MuscleVolumeTarget]) -> [String: Int] {
        var firstBySlug: [String: Int] = [:]
        for target in targets {
            guard let slug = target.muscle?.slug, firstBySlug[slug] == nil else { continue }
            firstBySlug[slug] = target.mev
        }
        var mev: [String: Int] = [:]
        for muscle in muscles {
            if let value = firstBySlug[muscle.slug] { mev[muscle.slug] = value }
        }
        return mev
    }

    /// The muscles of `mev` that `volumes` trained, but below MEV, with their
    /// rounded weighted sets. A muscle with no sets is not under-trained here:
    /// the recap leaves it out.
    static func underTrained(_ volumes: [String: WeightedSetTotal], mev: [String: Int]) -> [String: Int] {
        var under: [String: Int] = [:]
        for (slug, minimum) in mev {
            let sets = volumes[slug]?.totalSetsRounded ?? 0
            if sets > 0 && sets < minimum { under[slug] = sets }
        }
        return under
    }

}
