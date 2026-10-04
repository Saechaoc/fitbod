//
//  SessionLoggerCopyTests.swift
//  fitbodTests
//
//  Copy + wiring anchors for the active-workout screen (milestone 1,
//  Chalkline redesign — docs/design/screens.md § Active workout). The
//  views are pure SwiftUI; rendering is exercised by the XCUITest journey.
//  This suite pins, in source, the strings the spec fixes and the calls
//  that carry the screen's guarantees (one app-wide rest timer bound to the
//  session, validated completion, delayed discard, VoiceOver
//  announcements), so a careless edit trips a test.
//
//  Supersedes the plan 04-01 anchors on SetTypeChip / InlineRPEChipRow /
//  DecimalRPEPickerSheet / PreviousColumn, which the redesign replaced
//  (set type → row context menu, RPE → per-row menu, previous → tappable
//  Previous column inside SetEntryRow).
//

import Foundation
import Testing
@testable import fitbod

@Suite("SessionLoggerCopy")
struct SessionLoggerCopyTests {

    @Test("verbatimCopy — active-workout strings and wiring present in source")
    func verbatimCopy() throws {
        // SessionLoggerView — toolbar, bottom action, dialogs.
        let logger = try SourceFile.read("fitbod/Sessions/SessionLoggerView.swift")
        let loggerStrings = [
            "\"Finish\"",
            "\"Finish workout\"",
            "\"Finish workout?\"",
            "\"No sets logged yet\"",
            "\"Log at least one set to save this workout, or discard it.\"",
            "\"Keep logging\"",
            "\"Discard workout\"",
            "\"Discard workout?\"",
            "\"All sets logged in this workout will be deleted. Your routine is not affected.\"",
            "\"Add exercise\"",
            "\"Workout notes\"",
            "\"Minimize workout\"",
            "\"Elapsed\"",
        ]
        for string in loggerStrings {
            #expect(logger.contains(string), "SessionLoggerView.swift should contain \(string)")
        }
        // One app-wide timer from the environment, bound to this session.
        #expect(logger.contains("@Environment(RestTimerEngine.self)"))
        #expect(logger.contains("restTimer.start("))
        #expect(logger.contains("sessionID: session.id"))
        #expect(logger.contains("restTimer.stop(ifBelongsTo: session.id)"))
        // Validated completion + announcement on error.
        #expect(logger.contains("WorkoutLogging.complete(entry"))
        #expect(logger.contains("UIAccessibility.post(notification: .announcement"))
        // Finish prunes/stamps; discard deletes only after the cover closes.
        #expect(logger.contains("WorkoutFinisher.finish(session, context: ctx)"))
        #expect(logger.contains("router.pendingDiscard = session"))

        // SessionExerciseCard — column labels, menus, set actions.
        let card = try SourceFile.read("fitbod/Sessions/SessionExerciseCard.swift")
        let cardStrings = [
            "\"Set\"", "\"Previous\"", "\"Reps\"", "\"RPE\"", "\"Sets\"",
            "\"Add set\"", "\"Delete set\"",
            "\"Swap exercise\"", "\"Pinned note\"", "\"Plate math\"",
            "\"Skip warm-ups\"", "\"Remove from workout\"", "\"Removed exercise\"",
            "\"Set type\"", "\"Working\"", "\"Warm-up\"", "\"Drop Set\"", "\"To Failure\"", "\"Rest-Pause\"",
        ]
        for string in cardStrings {
            #expect(card.contains(string), "SessionExerciseCard.swift should contain \(string)")
        }
        // Previous performance never reads the workout in progress.
        #expect(card.contains("excludingSessionID:"))
        // Labels share the rows' scaled column widths.
        #expect(card.contains("SetTableMetrics()"))

        // SetEntryRow — placeholders, glyphs, keyboards, accessibility.
        let row = try SourceFile.read("fitbod/Sessions/SetRow.swift")
        #expect(row.contains("Text(\"—\")"))                          // no previous set
        #expect(row.contains("\"checkmark\""))                        // complete glyph
        #expect(row.contains("\"No RPE\""))
        #expect(row.contains(".numbersAndPunctuation"))               // signed bodyweight load
        #expect(row.contains(".decimalPad"))
        #expect(row.contains(".numberPad"))
        #expect(row.contains("\"Complete set \\(setLabel)\""))
        #expect(row.contains("\"Logs the set and starts rest\""))
        #expect(row.contains("usesStackedLayout"))                    // adaptive layout
    }
}
