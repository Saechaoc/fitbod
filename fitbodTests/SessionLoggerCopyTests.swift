//
//  SessionLoggerCopyTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — UI-SPEC verbatim copy anchors for the new
//  SessionLogger surfaces. The views are pure SwiftUI; true visual
//  rendering is verified on-device. This suite anchors the source-level
//  invariants so a careless edit can't silently mutate the load-bearing
//  UI-SPEC copy strings.
//
//  One test function covering every new file (matches plan AC #19 — 1 test
//  in SessionLoggerCopyTests).
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

        // SessionLoggerView — UI-SPEC § Session logger toolbar + dialogs.
        let loggerSrc = try String(
            contentsOf: base.appendingPathComponent("SessionLoggerView.swift"),
            encoding: .utf8
        )
        #expect(loggerSrc.contains("\"Workout\""))                              // navigation title
        #expect(loggerSrc.contains("\"Finish\""))                                // toolbar button
        #expect(loggerSrc.contains("\"Discard\""))                               // toolbar button
        #expect(loggerSrc.contains("\"Finish Workout?\""))                       // confirmation title
        #expect(loggerSrc.contains("\"Keep Logging\""))                          // confirmation cancel
        #expect(loggerSrc.contains("\"Discard Workout?\""))                      // discard alert title
        #expect(loggerSrc.contains("\"No data will be saved.\""))                // discard alert body
        #expect(loggerSrc.contains("\"Notes\""))                                  // header chip
        #expect(loggerSrc.contains("systemName: \"clock\""))                     // elapsed icon
        #expect(loggerSrc.contains("systemName: \"square.and.pencil\""))         // notes icon
        #expect(loggerSrc.contains("RestTimerEngine.makeProduction()"))          // plan 02-03 factory wire
        #expect(loggerSrc.contains("entry.isComplete = true"))                   // commit semantics
        #expect(loggerSrc.contains("entry.completedAt = .now"))
        #expect(loggerSrc.contains("engine.start(seconds:"))

        // SessionExerciseCard — UI-SPEC verbatim column header row.
        let cardSrc = try String(
            contentsOf: base.appendingPathComponent("SessionExerciseCard.swift"),
            encoding: .utf8
        )
        #expect(cardSrc.contains("\"Set\""))
        #expect(cardSrc.contains("\"Previous\""))
        #expect(cardSrc.contains("\"Weight\""))
        #expect(cardSrc.contains("\"Reps\""))
        #expect(cardSrc.contains("\"RPE\""))
        #expect(cardSrc.contains("\"Add Set\""))

        // SetRow — UI-SPEC verbatim "—" placeholders + completion glyphs.
        let rowSrc = try String(
            contentsOf: base.appendingPathComponent("SetRow.swift"),
            encoding: .utf8
        )
        #expect(rowSrc.contains("\"—\""))                                        // weight/reps placeholder
        #expect(rowSrc.contains("checkmark.circle.fill"))                        // complete glyph
        #expect(rowSrc.contains("\"circle\""))                                   // incomplete glyph
        #expect(rowSrc.contains("equipment == .bodyweight"))                     // SESS-09 signed branch
        #expect(rowSrc.contains(".numbersAndPunctuation"))                       // SESS-09 keyboard
        #expect(rowSrc.contains("entry.weight > 0 && entry.reps > 0"))           // commit guard

        // SetTypeChip — UI-SPEC verbatim long-press menu labels + system colors.
        let chipSrc = try String(
            contentsOf: base.appendingPathComponent("SetTypeChip.swift"),
            encoding: .utf8
        )
        #expect(chipSrc.contains("\"Working\""))
        #expect(chipSrc.contains("\"Warm-up\""))
        #expect(chipSrc.contains("\"Drop Set\""))
        #expect(chipSrc.contains("\"To Failure\""))
        #expect(chipSrc.contains("\"Rest-Pause\""))
        #expect(chipSrc.contains("Color(.systemBlue)"))
        #expect(chipSrc.contains("Color(.systemOrange)"))
        #expect(chipSrc.contains("Color(.systemRed)"))
        #expect(chipSrc.contains("Color(.systemPurple)"))

        // InlineRPEChipRow — UI-SPEC 6/7/8/9/10 + 0.5s long-press.
        let rpeSrc = try String(
            contentsOf: base.appendingPathComponent("InlineRPEChipRow.swift"),
            encoding: .utf8
        )
        #expect(rpeSrc.contains("ForEach([6, 7, 8, 9, 10]"))
        #expect(rpeSrc.contains("onLongPressGesture(minimumDuration: 0.5)"))
        #expect(rpeSrc.contains("DecimalRPEPickerSheet"))

        // DecimalRPEPickerSheet — UI-SPEC stride 6.0...10.0 by 0.5 + wheel.
        let picker = try String(
            contentsOf: base.appendingPathComponent("DecimalRPEPickerSheet.swift"),
            encoding: .utf8
        )
        #expect(picker.contains("stride(from: 6.0, through: 10.0, by: 0.5)"))
        #expect(picker.contains(".pickerStyle(.wheel)"))
        #expect(picker.contains("\"RPE\""))                                      // navigation title

        // PreviousColumn — UI-SPEC "—" placeholder + matching-intent helper.
        let prevSrc = try String(
            contentsOf: base.appendingPathComponent("PreviousColumn.swift"),
            encoding: .utf8
        )
        #expect(prevSrc.contains("PreviousMatchingIntent.fetchTopWorkingSet"))
        #expect(prevSrc.contains("Text(\"—\")"))
    }
}
