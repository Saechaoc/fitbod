//
//  TempoParts.swift
//  fitbod
//
//  The one reading of a stored tempo (T145). A tempo is four dash-joined
//  parts, Ecc-Bot-Con-Top, such as "3-1-2-0", and a part left blank keeps
//  its place, so a Bot pause alone is "-1--". The session editor's tempo
//  fields and the logger's TempoEntryRow both read and write through it,
//  so editing one part leaves the others where they were.
//
//  Plain strings with no UI, so unit tests call it directly.
//

import Foundation

public enum TempoParts {

    /// Ecc, Bot, Con and Top.
    private static let count = 4

    /// The four parts of `tempo`, Ecc to Top, with "" for each blank part.
    /// A tempo with fewer parts, such as "-1" for a Bot pause, leaves the
    /// rest blank, and one with more keeps the rest in Top, so nothing
    /// stored is lost.
    public static func split(_ tempo: String?) -> [String] {
        let parts = (tempo ?? "")
            .split(separator: "-", maxSplits: count - 1, omittingEmptySubsequences: false)
            .map(String.init)
        return parts + Array(repeating: "", count: count - parts.count)
    }

    /// The four parts joined with dashes, or nil when every part is blank,
    /// so no blank tempo is stored.
    public static func join(_ parts: [String]) -> String? {
        parts.allSatisfy(\.isEmpty) ? nil : parts.joined(separator: "-")
    }
}
