//
//  LibraryLines.swift
//  fitbod
//
//  The Library's browse list as lines (RM-022): two or more listed rows of
//  one family fold into a family line that opens in place to its variants,
//  and any other row stands alone. A search lists rows, best first, with no
//  families.
//

import Foundation

enum LibraryLines {

    enum Line: Identifiable {
        /// A row on its own: it has no family, or it is the only listed row
        /// of its family.
        case exercise(Exercise)
        /// Two or more listed rows of one family, in `variantOrder`.
        case family(name: String, variants: [Exercise])

        var id: String {
            switch self {
            case .exercise(let exercise): exercise.id.uuidString
            case .family(let name, _): "family:" + name
            }
        }

        /// What the line shows and sorts by.
        var title: String {
            switch self {
            case .exercise(let exercise): exercise.name
            case .family(let name, _): name
            }
        }
    }

    /// The section after Z, for titles that do not start with a letter.
    private static let otherSection = "#"

    /// `rows` as lines in sections A to Z by title, then one "#" section
    /// for titles such as "3/4 Sit-Up". Lines in a section sort by title.
    static func sections(_ rows: [Exercise]) -> [(letter: String, lines: [Line])] {
        var lines: [Line] = []
        var families: [String: [Exercise]] = [:]
        for row in rows {
            if let family = row.familyName {
                families[family, default: []].append(row)
            } else {
                lines.append(.exercise(row))
            }
        }
        for (name, variants) in families {
            lines.append(variants.count == 1
                ? .exercise(variants[0])
                : .family(name: name, variants: variants.sorted(by: variantOrder)))
        }
        // The id breaks a tie, such as a custom exercise named like a family,
        // so the order does not change between launches.
        lines.sort { lhs, rhs in
            let order = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        }
        let sections = Dictionary(grouping: lines) { section(for: $0.title) }
        let letters = sections.keys.sorted { lhs, rhs in
            if lhs == otherSection { return false }
            if rhs == otherSection { return true }
            return lhs < rhs
        }
        return letters.map { ($0, sections[$0] ?? []) }
    }

    /// What a variant shows under its family: its label, or its name when
    /// it has none, as the standard version and a custom exercise do.
    static func variantTitle(_ exercise: Exercise) -> String {
        exercise.variantLabel ?? exercise.name
    }

    /// Rows with no variant label first (a standard version or a custom
    /// exercise), then by title.
    private static func variantOrder(_ lhs: Exercise, _ rhs: Exercise) -> Bool {
        if (lhs.variantLabel == nil) != (rhs.variantLabel == nil) { return lhs.variantLabel == nil }
        let order = variantTitle(lhs).localizedCaseInsensitiveCompare(variantTitle(rhs))
        return order == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : order == .orderedAscending
    }

    private static func section(for title: String) -> String {
        guard let first = title.first, first.isLetter else { return otherSection }
        return String(first).uppercased()
    }
}
