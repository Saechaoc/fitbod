// TodayWeek.swift
// fitbod
//
// The week Today's week board draws: seven days from the week start, each
// with the counted workouts finished that day and their working sets, and
// the week's totals. Pure, so the board's rules are tested without a view
// (RM-010).

import Foundation

struct TodayWeek: Equatable {

    struct Day: Equatable, Identifiable {
        /// Local midnight.
        let date: Date
        /// "MON", in the app's en_US header style.
        let label: String
        let isToday: Bool
        /// The name of the newest counted workout that day, if any.
        let workoutName: String?
        /// The day's counted workouts.
        let workouts: Int
        /// Working sets in those workouts, by the rule Volume counts.
        let workingSets: Int

        var id: Date { date }
    }

    let start: Date
    let days: [Day]

    var workouts: Int { days.reduce(0) { $0 + $1.workouts } }
    var workingSets: Int { days.reduce(0) { $0 + $1.workingSets } }

    /// "NOV 9–15", or "OCT 26–NOV 1" across a month boundary.
    var rangeLabel: String {
        let en = Locale(identifier: "en_US")
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let month = { (date: Date) in date.formatted(.dateTime.locale(en).month(.abbreviated)).uppercased() }
        let day = { (date: Date) in date.formatted(.dateTime.locale(en).day()) }
        return month(first) == month(last)
            ? "\(month(first)) \(day(first))–\(day(last))"
            : "\(month(first)) \(day(first))–\(month(last)) \(day(last))"
    }

    /// The week starting at `weekStart` as of `now`. `finished` may hold
    /// any workouts: only counted ones (finished, not empty) started inside
    /// the week appear, so an open workout never adds sets.
    @MainActor
    static func make(finished: [Session], weekStart: Date, now: Date, calendar: Calendar) -> TodayWeek {
        let en = Locale(identifier: "en_US")
        let today = calendar.startOfDay(for: now)
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: weekStart)) }
        let end = dates.last.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } ?? weekStart
        // The week first: counting reads each workout's sets.
        let inWeek = Array(SessionSetActions.countedWorkouts(
            finished.filter { $0.startedAt >= weekStart && $0.startedAt < end }))
        let byDay = Dictionary(grouping: inWeek) { calendar.startOfDay(for: $0.startedAt) }
        let days = dates.map { date in
            let workouts = (byDay[date] ?? []).sorted { $0.startedAt > $1.startedAt }
            return Day(
                date: date,
                label: date.formatted(.dateTime.locale(en).weekday(.abbreviated)).uppercased(),
                isToday: date == today,
                workoutName: workouts.first?.displayName,
                workouts: workouts.count,
                workingSets: workouts.reduce(0) { $0 + workingSets(in: $1) }
            )
        }
        return TodayWeek(start: weekStart, days: days)
    }

    /// The working sets Volume counts for a workout (`SetEntry.countsAsWork`).
    /// Cardio logs bouts, which Volume leaves out (RM-062).
    @MainActor
    static func workingSets(in session: Session) -> Int {
        (session.exercises ?? []).reduce(0) { total, exercise in
            exercise.exercise?.isCardio == true ? total : total + (exercise.sets ?? []).filter(\.countsAsWork).count
        }
    }
}
