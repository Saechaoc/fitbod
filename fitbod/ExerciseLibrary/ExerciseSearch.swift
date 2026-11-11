//
//  ExerciseSearch.swift
//  fitbod
//
//  Word-prefix search over the exercise list (RM-022). It runs in memory
//  over the fetched rows, after the facet filters: the list already loads
//  every row when the field is empty, and a SwiftData predicate over one
//  string can neither read aliases word by word nor rank what it finds.
//
//  A row matches when every query word starts one of its words: the words
//  of its name, family, aliases, brand and equipment. "cable tricep ext"
//  finds "Triceps Extension (Cable)", and "stairmaster" finds "Stair
//  Climber" through its alias.
//

import Foundation

enum ExerciseSearch {

    /// The text one row is found by, split into words when the row is built.
    /// The Library builds its rows for each search; the catalog tests build
    /// them once and run thousands of searches over them.
    struct Row {
        let name: String
        let family: String?
        let aliases: [String]
        fileprivate let nameWords: [String]
        /// The searchable words of the name, family, brand and equipment.
        fileprivate let own: [String]
        /// Each alias without spaces, and its searchable words.
        fileprivate let aliasForms: [(joined: String, words: [String])]

        init(name: String, family: String? = nil, aliases: [String] = [], brand: String? = nil, equipment: String? = nil) {
            self.name = name
            self.family = family
            self.aliases = aliases
            nameWords = ExerciseSearch.words(in: name)
            own = [name, family, brand, equipment].compactMap { $0 }.flatMap(ExerciseSearch.searchable)
            aliasForms = aliases.map { (ExerciseSearch.words(in: $0).joined(), ExerciseSearch.searchable($0)) }
        }
    }

    /// How well a query found a row. Earlier cases sort first.
    enum Rank: Comparable {
        /// The query is the whole name or a whole alias.
        case whole
        /// The name starts with the query, or with its first word.
        case nameStart
        case other
    }

    struct Hit: Equatable {
        let rank: Rank
        /// The alias that found the row, when the row's own words would not
        /// have: the list shows it under the name.
        let alias: String?
    }

    /// Equipment as lifters shorten it.
    private static let shortForms = ["db": "dumbbell", "bb": "barbell", "kb": "kettlebell", "bw": "bodyweight"]

    /// `text` lowercased, without diacritics, split at anything that is not
    /// a letter or a digit: "Pull-Up" and "pull up" are both ["pull", "up"].
    static func words(in text: String) -> [String] {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// The words a text can be found by: its own, and each pair of
    /// neighbours joined, so "pullup" finds "Pull-Up".
    static func searchable(_ text: String) -> [String] {
        let words = words(in: text)
        return words + zip(words, words.dropFirst()).map(+)
    }

    /// The forms a query word may take: itself, a short form spelled out,
    /// and a plural without its ending, so "db curls" finds "Dumbbell Curl".
    static func forms(of word: String) -> [String] {
        var forms = [word]
        if let long = shortForms[word] { forms.append(long) }
        if word.count > 3, word.hasSuffix("s") { forms.append(String(word.dropLast())) }
        if word.count > 4, word.hasSuffix("es") { forms.append(String(word.dropLast(2))) }
        return forms
    }

    /// Every query word starts one of `candidates`. Two neighbouring query
    /// words may also count as one, so "pull down" finds "Pulldown".
    static func covers(_ query: ArraySlice<String>, in candidates: [String]) -> Bool {
        guard let first = query.first else { return true }
        func starts(_ word: String) -> Bool {
            forms(of: word).contains { form in candidates.contains { $0.hasPrefix(form) } }
        }
        if starts(first), covers(query.dropFirst(), in: candidates) { return true }
        if let second = query.dropFirst().first, starts(first + second) {
            return covers(query.dropFirst(2), in: candidates)
        }
        return false
    }

    /// How `query` finds `row`, or nil when it does not. An empty query
    /// finds every row.
    static func hit(_ query: String, in row: Row) -> Hit? {
        hit(words(in: query), in: row)
    }

    private static func hit(_ queryWords: [String], in row: Row) -> Hit? {
        guard !queryWords.isEmpty else { return Hit(rank: .other, alias: nil) }
        // Compared without spaces, so "situp" is the whole of "Sit-Up".
        let query = queryWords.joined()
        let name = row.nameWords.joined()
        let ownCovers = covers(queryWords[...], in: row.own)

        if name == query { return Hit(rank: .whole, alias: nil) }
        if let index = row.aliasForms.firstIndex(where: { $0.joined == query }) {
            return Hit(rank: .whole, alias: ownCovers ? nil : row.aliases[index])
        }
        if ownCovers {
            let leads = name.hasPrefix(query)
                || forms(of: queryWords[0]).contains { row.nameWords.first?.hasPrefix($0) == true }
            return Hit(rank: leads ? .nameStart : .other, alias: nil)
        }
        // The row's own words fall short: the first alias that completes them.
        let index = row.aliasForms.firstIndex { covers(queryWords[...], in: row.own + $0.words) }
        return index.map { Hit(rank: .other, alias: row.aliases[$0]) }
    }

    /// The items `query` finds, best first, then by name.
    static func results<Item>(
        _ query: String, in items: [Item], row: (Item) -> Row
    ) -> [(item: Item, hit: Hit)] {
        let queryWords = words(in: query)
        var found: [(item: Item, hit: Hit, name: String)] = []
        for item in items {
            let row = row(item)
            if let hit = hit(queryWords, in: row) { found.append((item, hit, row.name)) }
        }
        found.sort { lhs, rhs in
            if lhs.hit.rank != rhs.hit.rank { return lhs.hit.rank < rhs.hit.rank }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return found.map { (item: $0.item, hit: $0.hit) }
    }
}

extension ExerciseSearch.Row {
    /// What a stored exercise is found by.
    init(_ exercise: Exercise) {
        self.init(
            name: exercise.name,
            family: exercise.familyName,
            aliases: exercise.aliasesJoined.split(separator: "|").map(String.init),
            brand: exercise.brand,
            equipment: exercise.equipment.displayName
        )
    }
}
