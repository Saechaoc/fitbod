//
//  WeeklyRecapTriggerTests.swift
//  fitbodTests
//
//  Pins WeeklyRecapTrigger.evaluate (the pure-function helper that
//  drives VOL-07 sheet presentation in RootView) per RESEARCH §12.1
//  + Pitfalls #7 (Calendar.isDate date comparison) and #8 (re-firing
//  prevention).
//

import Foundation
import Testing
@testable import fitbod

@Suite("WeeklyRecapTrigger")
struct WeeklyRecapTriggerTests {

    // MARK: - 1. First launch of new Monday with sessions → fire

    @Test("First launch of new Monday with prior-week sessions → present + mark seen")
    func firstLaunchOfNewMondayWithSessionsFiresPresentation() {
        let thisMonday = Date(timeIntervalSince1970: 1_716_336_000)
        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMonday,
            lastShown: nil,
            hasSessionsLastWeek: true
        )
        #expect(decision.shouldPresent == true)
        #expect(decision.shouldMarkSeen == true)
    }

    // MARK: - 2. Re-launch within same week → suppress

    @Test("Re-launch within the same week → suppress (lastShown matches thisMonday)")
    func reLaunchSameWeekSuppresses() {
        let thisMonday = Date(timeIntervalSince1970: 1_716_336_000)
        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMonday,
            lastShown: thisMonday,
            hasSessionsLastWeek: true
        )
        #expect(decision.shouldPresent == false)
        #expect(decision.shouldMarkSeen == false)
    }

    // MARK: - 3. Zero sessions last week → skip but mark seen

    @Test("Zero sessions last week → skip presentation but mark seen (Pitfall #8)")
    func zeroSessionsLastWeekMarksSeenWithoutPresenting() {
        let thisMonday = Date(timeIntervalSince1970: 1_716_336_000)
        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMonday,
            lastShown: nil,
            hasSessionsLastWeek: false
        )
        #expect(decision.shouldPresent == false)
        #expect(decision.shouldMarkSeen == true)
    }

    // MARK: - 4. Next Monday re-fires after prior dismissal

    @Test("Next Monday after lastShown → re-fire")
    func nextMondayAfterLastShownRefires() {
        let lastMonday = Date(timeIntervalSince1970: 1_716_336_000)
        let nextMonday = lastMonday.addingTimeInterval(7 * 86_400)
        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: nextMonday,
            lastShown: lastMonday,
            hasSessionsLastWeek: true
        )
        #expect(decision.shouldPresent == true)
        #expect(decision.shouldMarkSeen == true)
    }

    // MARK: - 5. Pitfall #7: same-day comparison via .day granularity

    @Test("Pitfall #7: same-day comparison via Calendar.isDate(toGranularity: .day) handles micro-second skew")
    func pitfall7CalendarIsDateHandlesSameDayDifferentTime() {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        guard let baseMonday = cal.date(from: DateComponents(year: 2026, month: 5, day: 18)) else {
            Issue.record("failed to build base Monday date")
            return
        }
        // lastShown a few seconds into the same day; thisMonday many
        // hours later but still SAME calendar day → suppressed.
        let lastShownEarly = baseMonday.addingTimeInterval(1)
        let thisMondayLater = baseMonday.addingTimeInterval(45_000) // ~12:30 same day

        let decision = WeeklyRecapTrigger.evaluate(
            thisMonday: thisMondayLater,
            lastShown: lastShownEarly,
            hasSessionsLastWeek: true,
            calendar: cal
        )
        #expect(decision.shouldPresent == false)
    }
}
