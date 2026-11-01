//
//  PRRowTextTests.swift
//  fitbodTests
//
//  T85, finding F91: a PR row's value wraps between the phrases a lifter
//  reads as one, never inside them. On the 390pt phone at default text a
//  weight PR's value ended a line with "@" and wrapped "RPE 9" under it.
//
//  The value is set in the row's type at every width from one line down to
//  the phrase's own width, so each place the value may break comes up at
//  one of them.
//

import CoreText
import Foundation
import Testing
@testable import fitbod

@Suite("PR row text")
struct PRRowTextTests {

    @Test("A weight PR's value keeps \"@ RPE 9\" whole at every width")
    func weightValueKeepsItsRPEWhole() {
        let value = PRRowText.value(kind: .weight, weight: 160, reps: 3, rpe: 9, unit: .lb)

        let split = wraps(of: value, downTo: "@ RPE 9").filter { lines in
            lines.first { $0.contains("@") }?.hasSuffix("@ RPE 9") != true
        }
        #expect(split.isEmpty, "The value breaks inside \"@ RPE 9\": \(split.sorted { $0.count < $1.count })")
    }

    /// The other value with an "@": a rep PR's weight follows it.
    @Test("A rep PR's value keeps \"@ 160 lb\" and \"RPE 9\" whole at every width")
    func repsValueKeepsItsWeightAndRPEWhole() {
        let value = PRRowText.value(kind: .reps, weight: 160, reps: 3, rpe: 9, unit: .lb)

        let split = wraps(of: value, downTo: "@ 160 lb,").filter { lines in
            lines.first { $0.contains("@") }?.contains("@ 160 lb") != true
                || lines.first { $0.contains("RPE") }?.hasSuffix("RPE 9") != true
        }
        #expect(split.isEmpty, "The value breaks inside \"@ 160 lb\" or \"RPE 9\": \(split.sorted { $0.count < $1.count })")
    }

    /// The no-break spaces only change where the value may wrap. VoiceOver
    /// reads the row's copy with plain spaces.
    @Test("The spoken value is the copy with plain spaces")
    func spokenValueReadsTheCopy() {
        let weight = PRRowText.value(kind: .weight, weight: 160, reps: 3, rpe: 9, unit: .lb)
        let reps = PRRowText.value(kind: .reps, weight: 160, reps: 3, rpe: 9, unit: .lb)

        #expect(PRRowText.spoken(weight) == "160 lb × 3 @ RPE 9")
        #expect(PRRowText.spoken(reps) == "3 reps @ 160 lb, RPE 9")
    }

    // MARK: - Helpers

    /// Each way the value wraps at the widths from one line down to
    /// `phrase`'s width, in steps of half a point, in the row's type
    /// (BRUDisplay's medium size). Lines read with plain spaces, trimmed.
    private func wraps(of value: String, downTo phrase: String) -> Set<[String]> {
        let font = CTFontCreateWithName(BRUFace.grotesk.rawValue as CFString, BRUDisplaySize.medium.pointSize, nil)
        func typeset(_ text: String) -> NSAttributedString {
            NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        }
        func width(_ text: NSAttributedString) -> Double {
            CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), nil, nil, nil)
        }

        let text = typeset(value)
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var wraps = Set<[String]>()
        var lineWidth = width(text).rounded(.up)
        let narrowest = width(typeset(phrase)).rounded(.up)
        while lineWidth >= narrowest {
            var lines: [String] = []
            var start = 0
            while start < text.length {
                let count = CTTypesetterSuggestLineBreak(typesetter, start, lineWidth)
                let line = text.attributedSubstring(from: NSRange(location: start, length: count)).string
                lines.append(line.replacing("\u{00A0}", with: " ").trimmingCharacters(in: .whitespaces))
                start += count
            }
            wraps.insert(lines)
            lineWidth -= 0.5
        }
        return wraps
    }
}
