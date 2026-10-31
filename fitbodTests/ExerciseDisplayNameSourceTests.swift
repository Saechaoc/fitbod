//
//  ExerciseDisplayNameSourceTests.swift
//  fitbodTests
//
//  T30, review item 21. `Exercise.canonicalName` is the lowercased search
//  key, "barbell bench press - medium grip"; screens show `Exercise.name`.
//  These files once put the key on screen, so in them it may only sort or
//  search: as a sort key path, on either side of a comparison, or as the
//  text a search looks in. Any other use could feed text on screen.
//

import Foundation
import Testing

@Suite("Exercise display names")
struct ExerciseDisplayNameSourceTests {

    @Test(
        "canonicalName never feeds text on screen",
        arguments: [
            "Fatigue/PerMuscleDetailView.swift",
            "Fatigue/WeeklyRecapSheet.swift",
            "ExerciseLibrary/ExerciseHistoryView.swift",
            "Views/LiftListRow.swift",
            "Fatigue/TryVariationSheet.swift",
        ]
    )
    func canonicalNameOnlySortsOrSearches(in path: String) throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("fitbod")
            .appendingPathComponent(path)
        let uses = Self.displayUses(in: try String(contentsOf: url, encoding: .utf8))
            .map { "\(path):\($0.line): \($0.code)" }

        #expect(
            uses.isEmpty,
            "Show the exercise's name, not canonicalName, the lowercased search key:\n\(uses.joined(separator: "\n"))"
        )
    }

    @Test("The check catches canonicalName shown as text and lets sorting and search through")
    func checkCatchesDisplayUses() {
        let shown = [
            "Text(exercise.canonicalName)",
            "exerciseName: entry.exercise.canonicalName,",
            "routineExercise.exercise?.canonicalName ?? routineExercise.exercise?.name ?? \"Exercise\"",
            "Text(\"\\(exercise.canonicalName) sets\")",
            "Text(exercises.map(\\.canonicalName).joined(separator: \", \"))",
        ]
        for code in shown {
            #expect(Self.displayUses(in: code).count == 1, "The check must catch: \(code)")
        }

        let sortsOrSearches = [
            "return Array(logged.sorted { $0.canonicalName < $1.canonicalName }.prefix(3))",
            "sort: \\Exercise.canonicalName,",
            "ex.canonicalName.contains(normalizedSearch)",
            "predicate: #Predicate<Exercise> { $0.canonicalName == target }",
            "//   exercise.canonicalName in BRUFont.displayLarge 32pt",
            "Text(\"https://example.com\") // was exercise.canonicalName",
        ]
        for code in sortsOrSearches {
            #expect(Self.displayUses(in: code).isEmpty, "The check must let through: \(code)")
        }
    }

    // MARK: - Check

    /// Each line of `source` with a `canonicalName` that neither sorts nor
    /// searches, numbered from 1. Comments do not count.
    static func displayUses(in source: String) -> [(line: Int, code: String)] {
        source.components(separatedBy: "\n").enumerated().compactMap { offset, line -> (line: Int, code: String)? in
            let code = String(withoutComment(line))
            var searchStart = code.startIndex
            while let found = code.range(of: "canonicalName", range: searchStart..<code.endIndex) {
                if !sortsOrSearches(code, at: found) {
                    return (offset + 1, code.trimmingCharacters(in: .whitespaces))
                }
                searchStart = found.upperBound
            }
            return nil
        }
    }

    /// True when the `canonicalName` at `range` is a sort key path, either
    /// side of a comparison, or the text a search looks in.
    private static func sortsOrSearches(_ code: String, at range: Range<String.Index>) -> Bool {
        let before = code[..<range.lowerBound]
        // The receiver, such as `$0.`, `entry.exercise.` or `\Exercise.`.
        let receiver = before.reversed().prefix { $0.isLetter || $0.isNumber || "$_?!.\\".contains($0) }
        let lead = before.dropLast(receiver.count).trimmingCharacters(in: .whitespaces)
        if receiver.contains("\\") {
            // Only as a sort order: `map(\.canonicalName)` could feed text.
            return ["sort:", "SortDescriptor(", "KeyPathComparator("].contains { lead.hasSuffix($0) }
        }
        let after = code[range.upperBound...].trimmingCharacters(in: .whitespaces)
        let comparisons = ["<", ">", "==", "!="]
        let searches = [".contains(", ".localizedStandardContains(", ".hasPrefix("]
        return comparisons.contains { lead.hasSuffix($0) || after.hasPrefix($0) }
            || searches.contains { after.hasPrefix($0) }
    }

    /// `line` up to its `//` comment. A `//` inside a string literal starts
    /// none.
    private static func withoutComment(_ line: String) -> Substring {
        var inString = false
        var previous: Character = " "
        for index in line.indices {
            let character = line[index]
            if character == "\"" && previous != "\\" {
                inString.toggle()
            } else if character == "/" && previous == "/" && !inString {
                return line[..<line.index(before: index)]
            }
            previous = character
        }
        return line[...]
    }
}
