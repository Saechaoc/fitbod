//
//  TrainingDaysWriter.swift
//  fitbod
//
//  Phase 8-02 — SPEC-8-TRAININGDAYS: sort-at-write service.
//
//  `Block.trainingDays` stores weekday ints verbatim (no sort at read).
//  This utility is the ONLY place sorting happens — callers invoke it once
//  at write time (day-picker save, block-lifecycle edit). A later locale or
//  region change must not remap stored days (spec §3/§5).
//
//  Calendar injection follows the MondayAtMidnight value-copy precedent:
//  pass `calendar: Calendar = .current` by value so the copy is captured at
//  call time and no mutation ever touches the caller's Calendar.current.
//

import Foundation

/// Caseless namespace enum for training-day sort utilities.
///
/// Usage:
/// ```swift
/// block.trainingDays = TrainingDaysWriter.sort(weekdays: pickedDays)
/// ```
/// Pass an explicit `calendar:` in tests to pin locale behaviour.
public enum TrainingDaysWriter {

    /// Returns `weekdays` sorted in the caller's locale week order.
    ///
    /// - Parameters:
    ///   - weekdays: Raw weekday integers (1 = Sunday … 7 = Saturday per
    ///     `NSCalendar` / `Calendar` contract). Duplicates are preserved.
    ///   - calendar: The calendar whose `firstWeekday` drives the sort.
    ///     Defaults to `Calendar.current` — value-copied at call time so
    ///     subsequent locale changes have no effect on already-sorted arrays.
    /// - Returns: A new array sorted so that the locale's first weekday comes
    ///   first, wrapping around the end of the week.
    public static func sort(weekdays: [Int], using calendar: Calendar = .current) -> [Int] {
        let firstWeekday = calendar.firstWeekday // 1=Sun, 2=Mon per NSCalendar contract
        return weekdays.sorted { a, b in
            let normA = (a - firstWeekday + 7) % 7
            let normB = (b - firstWeekday + 7) % 7
            return normA < normB
        }
    }
}
