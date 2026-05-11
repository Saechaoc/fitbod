//
//  RestTimerOverlayCopyTests.swift
//  fitbodTests
//
//  Verifies the `RestTimerOverlay` source contains UI-SPEC verbatim copy
//  strings, the reduced-motion environment wire-up, and the TimelineView
//  1s-tick pattern. The overlay is a SwiftUI View — true visual rendering
//  is verified on-device by the user; these unit tests anchor the
//  source-level invariants so a careless edit can't silently mutate the
//  load-bearing UI-SPEC copy.
//
//  Three test functions (matches plan AC #13):
//    1. verbatimCopyAnchors                — UI-SPEC strings literal in source
//    2. reduceMotionWiredThroughEnvironment — @Environment(\.accessibilityReduceMotion)
//                                              consumed + forwarded to the progress ring
//    3. timelineViewTickEverySecond         — both render paths use
//                                              TimelineView(.periodic(from:, by: 1))
//

import Foundation
import Testing
@testable import fitbod

@Suite("RestTimerOverlayCopy")
struct RestTimerOverlayCopyTests {

    @Test("verbatimCopyAnchors — UI-SPEC strings present in RestTimerOverlay source")
    func verbatimCopyAnchors() throws {
        // Read the on-disk source. (Build-time grep is more typical;
        // this test executes a runtime fixture against the source file
        // for parse-clean strictness.)
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions/RestTimer/RestTimerOverlay.swift")
        let src = try String(contentsOf: url, encoding: .utf8)

        // UI-SPEC § Rest timer (verbatim):
        #expect(src.contains("\"· Rest\""))               // collapsed pill suffix
        #expect(src.contains("\"Rest Timer\""))           // expanded header
        #expect(src.contains("\"−15s\""))                  // expanded "−15s" button
        #expect(src.contains("\"+15s\""))                  // expanded "+15s" button
        #expect(src.contains("\"Skip\""))                  // skip text button
        #expect(src.contains("\"Prescribed: \\(engine.targetSeconds)s\""))   // footer

        // UI-SPEC accessibility verbatim labels:
        #expect(src.contains("\"Add 15 seconds\""))
        #expect(src.contains("\"Subtract 15 seconds\""))
        #expect(src.contains("\"Skip remaining rest\""))
        #expect(src.contains("\"Tap to expand controls\""))
    }

    @Test("reduceMotionWiredThroughEnvironment")
    func reduceMotionWiredThroughEnvironment() throws {
        // The progress ring takes `reduceMotion: Bool` and gates the
        // animation. Read the source and grep for the wire-up.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions/RestTimer/RestTimerOverlay.swift")
        let src = try String(contentsOf: url, encoding: .utf8)

        #expect(src.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(src.contains("reduceMotion: reduceMotion"))
    }

    @Test("timelineViewTickEverySecond")
    func timelineViewTickEverySecond() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions/RestTimer/RestTimerOverlay.swift")
        let src = try String(contentsOf: url, encoding: .utf8)

        // The collapsed pill AND the expanded body both wrap in
        // TimelineView(.periodic(from:, by: 1)) so the Date.now-derived
        // countdown re-renders once per second.
        #expect(src.contains("TimelineView(.periodic(from:"))
        #expect(src.contains("by: 1)"))
    }
}
