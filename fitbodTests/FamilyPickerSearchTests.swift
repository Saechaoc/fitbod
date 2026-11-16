//
//  FamilyPickerSearchTests.swift
//  fitbodTests
//
//  The custom exercise editor's family list search (RM-022): a query with
//  words lists the families whose names it finds, best first; a query with
//  no words is no search.
//

import Testing
@testable import fitbod

@Suite("Family picker search")
struct FamilyPickerSearchTests {

    /// Sorted A to Z, as the list passes them.
    private let families = ["Bench Press", "Cable Chest Fly", "Chest Press", "Medicine Ball Chest Pass", "Pull-Up"]

    @Test("Letter case and spaces around the query change nothing: \"CHEST\" and \"  chest \" find Chest Press first")
    func caseAndSpaces() {
        for query in ["chest", "CHEST", "  chest "] {
            #expect(
                FamilyPickerSheet.options(for: query, in: families)
                    == ["Chest Press", "Cable Chest Fly", "Medicine Ball Chest Pass"],
                "\(query)"
            )
        }
    }

    @Test("A query with no words, such as \"-\", is no search: None, then every family")
    func noWords() {
        for query in ["", "-", "!!", "  "] {
            #expect(FamilyPickerSheet.options(for: query, in: families) == [nil] + families.map { Optional($0) }, "\(query)")
        }
    }

    @Test("A word that names no family finds none")
    func noMatch() {
        #expect(FamilyPickerSheet.options(for: "zercher", in: families).isEmpty)
    }
}
