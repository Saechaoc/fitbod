//
//  UICopyRulesTests.swift
//  fitbodTests
//
//  Ticket T34, review item 25. The app's copy rules, read off every Swift
//  file under fitbod/. Outside comments, no string literal may
//
//    - send the user to the "Routines tab" or "in Routines", since the tab
//      is called Program, or offer "Remove from Session", since a logged
//      workout is a "workout" on screen; or
//    - put an interpolated count straight before a plural noun, as in
//      "\(count) sessions", which reads "1 sessions". A count label goes
//      through BRUCountLabel.text, so it reads "1 session" and "2 sessions".
//
//  Each failure names the file and line. The suite also pins the back and
//  close labels T34 fixed, since a screen no test can open is one of them,
//  and the per-week rate History shows.
//

import Foundation
import Testing
@testable import fitbod

@Suite("UI copy rules")
struct UICopyRulesTests {

    /// Retired copy, as patterns. "in Routines" keeps its case, since
    /// "used in routines" would be fine.
    private static let retiredPhrases: [(pattern: String, ignoresCase: Bool)] = [
        (#"\bRoutines tab\b"#, true),
        (#"\bin Routines\b"#, false),
        (#"\bRemove from Session\b"#, true),
    ]

    /// The plural nouns a count label must not write out after a count, in
    /// any case.
    private static let countNouns = ["sessions", "sets", "exercises", "weeks", "days", "reps"]

    /// Interpolations before one of those nouns that are not whole counts,
    /// by file, with the reason.
    private static let notWholeCounts: [(file: String, interpolation: String, reason: String)] = [
        ("fitbod/ExerciseLibrary/ExerciseHistoryView.swift", "intentFilter!.rawValue.capitalized",
         "an intent's name, as in \"No Strength sets\""),
        ("fitbod/Sessions/WhyThisWeightSheet.swift", #"String(format: "%.1f", rir)"#,
         "a fractional count, such as \"1.5 reps\", which is always plural; a whole one takes BRUCountLabel"),
    ]

    @Test("No string literal sends the user to the Routines tab or offers Remove from Session")
    func noRetiredCopy() throws {
        let patterns = try Self.retiredPhrases.map {
            try NSRegularExpression(pattern: $0.pattern, options: $0.ignoresCase ? [.caseInsensitive] : [])
        }
        for literal in try SourceLiteral.inApp() {
            let text = literal.text
            let whole = NSRange(text.startIndex..., in: text)
            for (pattern, phrase) in zip(patterns, Self.retiredPhrases)
            where pattern.firstMatch(in: text, range: whole) != nil {
                Issue.record("\(literal.file):\(literal.line): \"\(text)\" matches \(phrase.pattern)")
            }
        }
    }

    @Test("A count before a plural noun goes through BRUCountLabel")
    func countsUseThePluralHelper() throws {
        var usedExemptions = Set<Int>()
        for literal in try SourceLiteral.inApp() {
            for (count, next) in zip(literal.parts, literal.parts.dropFirst()) {
                guard case .interpolation(let expression) = count.kind,
                      case .text(let text) = next.kind,
                      let noun = Self.leadingCountNoun(of: text) else { continue }
                if let exemption = Self.notWholeCounts.firstIndex(where: {
                    $0.file == literal.file && $0.interpolation == expression
                }) {
                    usedExemptions.insert(exemption)
                    continue
                }
                Issue.record("""
                    \(literal.file):\(count.line): "\\(\(expression)) \(noun)" must be \
                    BRUCountLabel.text(\(expression), "\(noun.dropLast())")
                    """)
            }
        }
        for (index, exemption) in Self.notWholeCounts.enumerated() where !usedExemptions.contains(index) {
            Issue.record("\(exemption.file) no longer puts \\(\(exemption.interpolation)) before a plural noun; drop its exemption")
        }
    }

    /// One of the pushed screens goes back only from a deleted workout's
    /// summary, which no test can open, since a finished workout cannot be
    /// deleted. CopySweepUITests reads the rest off the screen.
    @Test("Pushed screens go back with ‹ BACK, and the weekly recap closes with DONE")
    func backAndCloseLabels() throws {
        let pushedScreens: Set = [
            "fitbod/ExerciseLibrary/ExerciseHistoryView.swift",
            "fitbod/Fatigue/PerMuscleDetailView.swift",
            "fitbod/Progress/ExercisePRsView.swift",
            "fitbod/Progress/ExerciseProgressView.swift",
            "fitbod/Sessions/SessionDetailView.swift",
            "fitbod/Sessions/SessionHistoryRoute.swift",
            "fitbod/Sessions/SessionHistoryView.swift",
        ]
        let recap = "fitbod/Fatigue/WeeklyRecapSheet.swift"
        let literals = try SourceLiteral.inApp().filter { pushedScreens.contains($0.file) || $0.file == recap }
        for literal in literals where literal.text == "‹" {
            Issue.record("\(literal.file):\(literal.line): a bare ‹ must read ‹ Back, or Done on the weekly recap")
        }
        for file in pushedScreens.sorted() where !literals.contains(where: { $0.file == file && $0.text == "‹ Back" }) {
            Issue.record("\(file) must go back with ‹ Back")
        }
        #expect(literals.contains(where: { $0.file == recap && $0.text == "Done" }), "The weekly recap must close with Done")
    }

    /// The noun `text` starts with, after any spaces, when it is one of
    /// `countNouns` and a whole word.
    private static func leadingCountNoun(of text: String) -> String? {
        let rest = text.drop(while: \.isWhitespace)
        return countNouns.lazy.compactMap { noun -> String? in
            let head = rest.prefix(noun.count)
            guard head.lowercased() == noun, !(rest.dropFirst(noun.count).first?.isLetter ?? false) else { return nil }
            return String(head)
        }.first
    }
}

@Suite("Per-week rate")
struct PerWeekRateTests {

    /// Tradeoffs, "Per-week rate": PER WEEK shows up to two decimals with
    /// trailing zeros trimmed. It rounded one workout in four weeks to 0.2.
    @Test("PER WEEK shows up to two decimals, trailing zeros trimmed", arguments: [
        (1, "0.25"), (2, "0.5"), (8, "2"),
    ])
    func perWeek(workouts: Int, label: String) {
        #expect(SessionHistoryFormat.perWeek(workoutsInFourWeeks: workouts, locale: Locale(identifier: "en_US")) == label)
    }
}

// MARK: - Source literals

/// A string literal in the app's source: its file from the repo root, the
/// line it starts on, and its text and interpolations in order.
private struct SourceLiteral {
    struct Part {
        enum Kind {
            case text(String)
            case interpolation(String)
        }

        let kind: Kind
        let line: Int
    }

    let file: String
    let line: Int
    let parts: [Part]

    /// The literal's text, with U+FFFC for each interpolation, so a phrase
    /// never runs across one.
    var text: String {
        parts.map { part in
            switch part.kind {
            case .text(let text): text
            case .interpolation: "\u{FFFC}"
            }
        }.joined()
    }

    /// Every literal in every Swift file under fitbod/, file by file.
    static func inApp() throws -> [SourceLiteral] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let app = root.appendingPathComponent("fitbod")
        let enumerator = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
        try #require(files.contains { $0.lastPathComponent == "BRUCountLabel.swift" },
                     "The scan must read the app's source, but found \(files.count) Swift files under \(app.path)")
        return try files.flatMap { url in
            let file = String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            var scanner = LiteralScanner(try String(contentsOf: url, encoding: .utf8))
            scanner.scan()
            return scanner.literals.map { SourceLiteral(file: file, line: $0.line, parts: $0.parts) }
        }
    }
}

/// Finds a Swift file's string literals outside comments. It knows the
/// Swift it needs: line comments and nested block comments, raw (#"…"#)
/// and multi-line literals, escapes, and interpolations, whose own literals
/// it finds too. It reads UTF-8 bytes, since every delimiter is ASCII.
private struct LiteralScanner {
    private let bytes: [UInt8]
    private var index = 0
    private var line = 1
    private(set) var literals: [(line: Int, parts: [SourceLiteral.Part])] = []

    private static let quote = UInt8(ascii: "\"")
    private static let hash = UInt8(ascii: "#")
    private static let backslash = UInt8(ascii: "\\")
    private static let openParen = UInt8(ascii: "(")
    private static let closeParen = UInt8(ascii: ")")
    private static let slash = UInt8(ascii: "/")
    private static let star = UInt8(ascii: "*")
    private static let newline = UInt8(ascii: "\n")

    init(_ source: String) {
        bytes = Array(source.utf8)
    }

    mutating func scan() {
        while index < bytes.count {
            if skipComment() { continue }
            if let hashes = literalOpening() {
                scanLiteral(hashes: hashes)
            } else {
                step()
            }
        }
    }

    private func byte(at offset: Int) -> UInt8? {
        index + offset < bytes.count ? bytes[index + offset] : nil
    }

    /// Moves one byte on, counting lines.
    private mutating func step() {
        if bytes[index] == Self.newline { line += 1 }
        index += 1
    }

    /// Skips the comment that starts at the current byte, if one does.
    private mutating func skipComment() -> Bool {
        guard byte(at: 0) == Self.slash else { return false }
        if byte(at: 1) == Self.slash {
            while index < bytes.count, bytes[index] != Self.newline { index += 1 }
            return true
        }
        guard byte(at: 1) == Self.star else { return false }
        var depth = 0
        while index < bytes.count {
            if byte(at: 0) == Self.slash, byte(at: 1) == Self.star {
                depth += 1
                index += 2
            } else if byte(at: 0) == Self.star, byte(at: 1) == Self.slash {
                depth -= 1
                index += 2
                if depth == 0 { break }
            } else {
                step()
            }
        }
        return true
    }

    /// The number of #s before the literal that opens at the current byte,
    /// or nil when no literal opens there.
    private func literalOpening() -> Int? {
        var hashes = 0
        while byte(at: hashes) == Self.hash { hashes += 1 }
        return byte(at: hashes) == Self.quote ? hashes : nil
    }

    /// Whether `count` #s follow the current byte.
    private func hashesFollow(_ count: Int) -> Bool {
        (0..<count).allSatisfy { byte(at: 1 + $0) == Self.hash }
    }

    /// Whether the literal's closing delimiter starts at the current byte.
    private func closes(quotes: Int, hashes: Int) -> Bool {
        (0..<quotes).allSatisfy { byte(at: $0) == Self.quote }
            && (quotes..<(quotes + hashes)).allSatisfy { byte(at: $0) == Self.hash }
    }

    /// Reads the literal that opens after `hashes` #s at the current byte,
    /// and the literals inside its interpolations.
    private mutating func scanLiteral(hashes: Int) {
        let start = line
        index += hashes
        let quotes = byte(at: 1) == Self.quote && byte(at: 2) == Self.quote ? 3 : 1
        index += quotes
        var parts: [SourceLiteral.Part] = []
        var text: [UInt8] = []
        var textLine = line
        func endText() {
            guard !text.isEmpty else { return }
            parts.append(.init(kind: .text(String(decoding: text, as: UTF8.self)), line: textLine))
            text.removeAll()
        }
        while index < bytes.count {
            if closes(quotes: quotes, hashes: hashes) {
                index += quotes + hashes
                break
            }
            let current = bytes[index]
            if current == Self.backslash, hashesFollow(hashes) {
                let escaped = index + 1 + hashes
                if escaped < bytes.count, bytes[escaped] == Self.openParen {
                    endText()
                    let interpolationLine = line
                    index = escaped + 1
                    parts.append(.init(kind: .interpolation(scanInterpolation()), line: interpolationLine))
                    continue
                }
                if text.isEmpty { textLine = line }
                appendEscape(at: escaped, to: &text)
                continue
            }
            // A single-line literal left open ends with its line.
            if quotes == 1, current == Self.newline { break }
            if text.isEmpty { textLine = line }
            text.append(current)
            step()
        }
        endText()
        literals.append((start, parts))
    }

    /// Reads an interpolation up to its closing parenthesis, finding the
    /// literals inside it, and returns its source.
    private mutating func scanInterpolation() -> String {
        let start = index
        var depth = 1
        while index < bytes.count {
            if skipComment() { continue }
            if let hashes = literalOpening() {
                scanLiteral(hashes: hashes)
                continue
            }
            if bytes[index] == Self.openParen { depth += 1 }
            if bytes[index] == Self.closeParen {
                depth -= 1
                if depth == 0 {
                    let source = String(decoding: bytes[start..<index], as: UTF8.self)
                    index += 1
                    return source.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            step()
        }
        return String(decoding: bytes[start...], as: UTF8.self)
    }

    /// Appends what the escape whose character is at `escaped` stands for,
    /// and moves past it.
    private mutating func appendEscape(at escaped: Int, to text: inout [UInt8]) {
        guard escaped < bytes.count else {
            index = bytes.count
            return
        }
        switch bytes[escaped] {
        case UInt8(ascii: "n"): text.append(Self.newline)
        case UInt8(ascii: "t"): text.append(UInt8(ascii: "\t"))
        case UInt8(ascii: "r"): text.append(UInt8(ascii: "\r"))
        case UInt8(ascii: "0"): text.append(0)
        case UInt8(ascii: "u"):
            if let brace = bytes[escaped...].firstIndex(of: UInt8(ascii: "}")), escaped + 2 <= brace,
               let value = UInt32(String(decoding: bytes[(escaped + 2)..<brace], as: UTF8.self), radix: 16),
               let scalar = Unicode.Scalar(value) {
                text.append(contentsOf: Array(String(Character(scalar)).utf8))
                index = brace + 1
                return
            }
            text.append(bytes[escaped])
        case Self.newline:
            // A multi-line literal's line continuation.
            line += 1
        default:
            text.append(bytes[escaped])
        }
        index = escaped + 1
    }
}
