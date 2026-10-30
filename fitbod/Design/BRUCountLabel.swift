//
//  BRUCountLabel.swift
//  fitbod
//
//  The one plural rule for count labels (review item 25): a count and its
//  noun, singular only when the count is exactly 1, as in "0 sets", "1 set"
//  and "2 sets". An uppercase noun gets an uppercase plural, so labels such
//  as "1 SET LOGGED" and "TOTAL · 8 WEEKS" read right. A noun whose plural
//  is not the singular plus "s" passes its plural in, as "match" does with
//  "matches".
//
//  Plain strings with no UI, so unit tests call it directly. The app is not
//  localized, so String Catalog plural variants would buy nothing yet.
//

import Foundation

public enum BRUCountLabel {

    /// "1 set" or "2 sets"; "1 SET" or "2 SETS". Pass `plural` for a noun
    /// that does not just add "s".
    public static func text(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        let noun = count == 1 ? singular : plural ?? regularPlural(of: singular)
        return "\(count) \(noun)"
    }

    private static func regularPlural(of singular: String) -> String {
        let isUppercase = singular == singular.uppercased()
        return singular + (isUppercase ? "S" : "s")
    }
}
