//
//  RestTimerOverlayCopyTests.swift
//  fitbodTests
//
//  Rest timer dock + sheet (milestone 1, Chalkline redesign —
//  docs/design/screens.md § Rest timer). Anchors the copy and the
//  accessibility labels in source, the reduce-motion and 1 s tick wiring,
//  and — behaviourally — the countdown text helpers.
//
//    1. verbatimCopyAnchors                 — strings literal in source
//    2. reduceMotionWiredThroughEnvironment — @Environment(\.accessibilityReduceMotion)
//                                             gates the progress animation
//    3. timelineViewTickEverySecond         — dock and sheet re-render via
//                                             TimelineView(.periodic(from:, by: 1))
//    4. countdownText                       — "1:42" / "+0:18" and the
//                                             spoken VoiceOver values
//

import Foundation
import Testing
@testable import fitbod

@Suite("RestTimerOverlayCopy")
struct RestTimerOverlayCopyTests {

    private func source() throws -> String {
        try SourceFile.read("fitbod/Sessions/RestTimer/RestTimerOverlay.swift")
    }

    @Test("verbatimCopyAnchors — rest timer strings present in source")
    func verbatimCopyAnchors() throws {
        let src = try source()
        let strings = [
            "\"Rest timer\"",                 // dock VoiceOver label
            "\"Rest done\"",                  // overtime state
            "\"−15\"", "\"+15\"",             // dock adjust buttons
            "\"−15 s\"", "\"+15 s\"",         // sheet adjust buttons
            "\"Skip\"", "\"Done\"",
            "\"REST TIMER\"",                 // sheet title
            "\"Total rest\"",                 // presets header
            // Accessibility labels
            "\"Add 15 seconds\"",
            "\"Subtract 15 seconds\"",
            "\"Skip remaining rest\"",
            "\"Dismiss rest timer\"",
            "\"Double-tap for presets. Swipe up or down to change by 15 seconds.\"",
        ]
        for string in strings {
            #expect(src.contains(string), "RestTimerOverlay.swift should contain \(string)")
        }
        // VoiceOver swipe up/down adjusts by 15 s.
        #expect(src.contains(".accessibilityAdjustableAction"))
    }

    @Test("reduceMotionWiredThroughEnvironment")
    func reduceMotionWiredThroughEnvironment() throws {
        let src = try source()
        #expect(src.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(src.contains("reduceMotion ? nil : .linear(duration: 1)"))
    }

    @Test("timelineViewTickEverySecond")
    func timelineViewTickEverySecond() throws {
        let src = try source()
        // Both the dock and the sheet derive the countdown from the
        // absolute deadline and re-render once per second.
        #expect(src.components(separatedBy: "TimelineView(.periodic(from:").count - 1 >= 2)
        #expect(src.contains("by: 1)"))
    }

    @Test("countdownText — clock and spoken values, including overtime")
    func countdownText() {
        #expect(RestTimerText.clock(102) == "1:42")
        #expect(RestTimerText.clock(101.2) == "1:42")      // rounds up while counting down
        #expect(RestTimerText.clock(0) == "0:00")
        #expect(RestTimerText.clock(-18.6) == "+0:18")     // overtime counts up
        #expect(RestTimerText.spoken(102) == "1 minute 42 seconds left")
        #expect(RestTimerText.spoken(60) == "1 minute left")
        #expect(RestTimerText.spoken(1) == "1 second left")
        #expect(RestTimerText.spoken(-18) == "18 seconds over")
    }
}
