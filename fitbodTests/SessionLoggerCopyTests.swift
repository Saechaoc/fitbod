//
//  SessionLoggerCopyTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — UI-SPEC verbatim copy anchors for SessionLogger surfaces.
//
//  UPDATED (Phase 2.1 Plan 07 BRU rewrite): assertions for banned v1 tokens
//  (SF Symbols, system colors, Capsule) are removed because those surfaces
//  were rewritten to BRU in 02.1-07. The BRU-specific assertions live in
//  SessionLoggerBRUCopyTests.swift.
//
//  Surviving assertions cover: commit semantics, rest timer wiring, structural
//  copy (dialogs, accessibility labels) that are PRESERVED across the BRU rewrite.
//

import Foundation
import Testing
@testable import fitbod

@Suite("SessionLoggerCopy")
struct SessionLoggerCopyTests {

    @Test("verbatimCopy — UI-SPEC strings present in SessionLogger source")
    func verbatimCopy() throws {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Sessions")

        // SessionLoggerView — core structural strings preserved post-BRU-rewrite.
        let loggerSrc = try String(
            contentsOf: base.appendingPathComponent("SessionLoggerView.swift"),
            encoding: .utf8
        )
        #expect(loggerSrc.contains("\"Workout\""))                              // header center title
        #expect(loggerSrc.contains("\"Finish"))                                  // finish action present
        #expect(loggerSrc.contains("\"Discard"))                                 // discard action present
        #expect(loggerSrc.contains("\"No data will be saved.\""))                // discard alert body (verbatim)
        #expect(loggerSrc.contains("RestTimerEngine.makeProduction()"))          // plan 02-03 factory wire
        #expect(loggerSrc.contains("SessionSetActions.complete(entry, at: .now"))  // commit semantics (flip + stamp + save)
        #expect(loggerSrc.contains("SessionSetActions.uncomplete(entry"))       // tap a done set to undo
        #expect(loggerSrc.contains(".safeAreaInset(edge: .bottom"))             // rest timer dock mounted
        #expect(loggerSrc.contains("RestTimerOverlay(engine: engine)"))
        #expect(loggerSrc.contains("engine.start(seconds:"))

        // SessionExerciseCard — column headers preserved (BRU uppercase label form).
        let cardSrc = try String(
            contentsOf: base.appendingPathComponent("SessionExerciseCard.swift"),
            encoding: .utf8
        )
        // BRU uses uppercase via .textCase(.uppercase) on labelSmall — source strings
        // are stored uppercase in labelSmall form per UI-SPEC line 367 convention.
        #expect(cardSrc.contains("\"PREVIOUS\"") || cardSrc.contains("\"Previous\""))
        #expect(cardSrc.contains("\"WEIGHT\"") || cardSrc.contains("\"Weight\""))
        #expect(cardSrc.contains("\"REPS\"") || cardSrc.contains("\"Reps\""))
        #expect(cardSrc.contains("\"RPE\""))
        // "+ ADD SET" signal text button replaces "Add Set" per UI-SPEC line 387
        #expect(cardSrc.contains("ADD SET") || cardSrc.contains("Add Set"))

        // SetRow — "—" placeholder preserved; SetCompletionGlyph replaces SF Symbol.
        let rowSrc = try String(
            contentsOf: base.appendingPathComponent("SetRow.swift"),
            encoding: .utf8
        )
        #expect(rowSrc.contains("\"—\""))                                        // weight/reps placeholder
        #expect(rowSrc.contains("SetCompletionGlyph"))                           // BRU completion glyph
        #expect(rowSrc.contains("SessionSetActions.canComplete(entry)"))       // shared commit guard

        // SetTypeChip — UI-SPEC verbatim long-press menu labels (preserved).
        // System colors removed per BRU rewrite (02.1-07).
        let chipSrc = try String(
            contentsOf: base.appendingPathComponent("SetTypeChip.swift"),
            encoding: .utf8
        )
        #expect(chipSrc.contains("\"Working\""))
        #expect(chipSrc.contains("\"Warm-up\""))
        #expect(chipSrc.contains("\"Drop Set\""))
        #expect(chipSrc.contains("\"To Failure\""))
        #expect(chipSrc.contains("\"Rest-Pause\""))
        // BRU chip labels (new post-rewrite assertions)
        #expect(chipSrc.contains("\"W/UP\""))
        #expect(chipSrc.contains("\"DROP\""))
        #expect(chipSrc.contains("\"FAIL\""))
        #expect(chipSrc.contains("\"RP\""))

        // InlineRPEChipRow — 5 RPE values + 0.5s long-press preserved.
        let rpeSrc = try String(
            contentsOf: base.appendingPathComponent("InlineRPEChipRow.swift"),
            encoding: .utf8
        )
        #expect(rpeSrc.contains("[6, 7, 8, 9, 10]"))
        #expect(rpeSrc.contains("onLongPressGesture(minimumDuration: 0.5)"))
        #expect(rpeSrc.contains("DecimalRPEPickerSheet"))

        // DecimalRPEPickerSheet — wheel picker + stride preserved.
        let picker = try String(
            contentsOf: base.appendingPathComponent("DecimalRPEPickerSheet.swift"),
            encoding: .utf8
        )
        #expect(picker.contains("stride(from: 6.0, through: 10.0, by: 0.5)"))
        #expect(picker.contains(".pickerStyle(.wheel)"))
        #expect(picker.contains("\"RPE\""))

        // PreviousColumn — matching-intent helper preserved.
        let prevSrc = try String(
            contentsOf: base.appendingPathComponent("PreviousColumn.swift"),
            encoding: .utf8
        )
        #expect(prevSrc.contains("PreviousMatchingIntent.fetchTopWorkingSet"))
        #expect(prevSrc.contains("Text(\"—\")"))

        // Phase 3.1 (PIVOT-04 / D-11): IntentChip wired in SessionLoggerView.
        #expect(loggerSrc.contains("IntentChip(intent: session.intent)"))

        // IntentChip — BRU rewrite preserves verbatim accessibility label format.
        let chipViewBase = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fitbod/Views")
        let intentChipSrc = try String(
            contentsOf: chipViewBase.appendingPathComponent("IntentChip.swift"),
            encoding: .utf8
        )
        #expect(intentChipSrc.contains(
            ".accessibilityLabel(\"Intent: \\(intent.rawValue.capitalized)\")"
        ))
    }
}
