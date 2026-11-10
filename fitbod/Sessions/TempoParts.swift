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

    public enum ValidationError: LocalizedError {
        case invalidParts

        public var errorDescription: String? {
            "Enter one tempo part per field, without dashes."
        }
    }

    /// Ecc, Bot, Con and Top.
    private static let count = 4

    /// The four parts of `tempo`, Ecc to Top, with "" for each blank part.
    /// Legacy tempos with fewer parts are padded; extra parts are read as before.
    public static func split(_ tempo: String?) -> [String] {
        let parts = (tempo ?? "")
            .split(separator: "-", omittingEmptySubsequences: false)
            .map(String.init)
        return (0..<count).map { $0 < parts.count ? parts[$0] : "" }
    }

    /// The four parts joined with dashes, or nil when every part is blank,
    /// so no blank tempo is stored.
    public static func join(_ parts: [String]) throws -> String? {
        guard parts.count == count, parts.allSatisfy({ part in
            !part.unicodeScalars.contains {
                $0.properties.generalCategory == .dashPunctuation || $0.value == 0x2212
            }
        }) else { throw ValidationError.invalidParts }
        return parts.allSatisfy(\.isEmpty) ? nil : parts.joined(separator: "-")
    }
}
