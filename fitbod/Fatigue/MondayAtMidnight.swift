//
//  MondayAtMidnight.swift
//  fitbod
//
//  Phase 5 — shared Date helper for week-anchored calendar math per
//  RESEARCH §10 Pitfall #4. Uses Calendar.current with `firstWeekday`
//  flipped to Monday (= 2 in NSCalendar's 1-indexed weekday model)
//  before requesting the week's start. Avoids raw `Date - daysSince`
//  math which breaks across DST boundaries.
//
//  Defined here (not as a fileprivate extension inside
//  `FatigueSurfaceView.swift`) so RootView's deload advisory refresh
//  flow can call it without duplicating the logic.
//

import Foundation

extension Date {
    /// Monday-anchored midnight start of the calendar week containing
    /// `self`. When `weekStartsMonday` is true, applies
    /// `Calendar.current.firstWeekday = 2` before computing the
    /// week-of-year date components.
    public func mondayAtMidnightForToday(
        weekStartsMonday: Bool,
        calendar: Calendar = .current
    ) -> Date {
        var cal = calendar
        if weekStartsMonday {
            cal.firstWeekday = 2
        }
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: components) ?? self
    }
}
