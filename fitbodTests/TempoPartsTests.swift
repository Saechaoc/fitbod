//
//  TempoPartsTests.swift
//  fitbodTests
//
//  T145 (finding F380): a tempo is four dash-joined parts, Ecc-Bot-Con-Top,
//  and a blank part keeps its place. The session editor split a tempo with
//  `split(separator: "-")`, which drops empty parts, so a Bot pause alone,
//  stored "-1", read back as Ecc 1, and setting one part of a tempo with a
//  gap wrote its other parts back shifted. The session editor and the
//  logger both read and write a tempo through `TempoParts`.
//

import Testing
@testable import fitbod

@Suite("TempoParts")
struct TempoPartsTests {

    @Test("No tempo reads as four blank parts, and four blank parts store nil",
          arguments: [nil, ""] as [String?])
    func blankTempo(tempo: String?) {
        let parts = TempoParts.split(tempo)
        #expect(parts == ["", "", "", ""])
        #expect(TempoParts.join(parts) == nil)
    }

    @Test("A tempo reads back and joins back as entered", arguments: [
        ("3-1-2-0", ["3", "1", "2", "0"]),
        ("3--2-0", ["3", "", "2", "0"]),
    ])
    func tempoReadsBackAsEntered(tempo: String, parts: [String]) {
        #expect(TempoParts.split(tempo) == parts)
        #expect(TempoParts.join(parts) == tempo)
    }

    /// Each part alone, as the logger stores it, such as "-1--", and as the
    /// session editor stored it, without the blanks after it, such as "-1",
    /// which the editor read back as Ecc 1.
    @Test("Each part alone reads back in its own place", arguments: [
        (["3", "", "", ""], "3---", "3"),
        (["", "1", "", ""], "-1--", "-1"),
        (["", "", "2", ""], "--2-", "--2"),
        (["", "", "", "0"], "---0", "---0"),
    ])
    func eachPartAlone(parts: [String], tempo: String, editorTempo: String) {
        #expect(TempoParts.split(tempo) == parts)
        #expect(TempoParts.split(editorTempo) == parts)
        #expect(TempoParts.join(parts) == tempo)
    }

    /// The session editor wrote this back as "1-2--5".
    @Test("Setting one part leaves the others where they were")
    func settingOnePartKeepsTheOthers() {
        var parts = TempoParts.split("-1-2-")
        parts[3] = "5"
        #expect(TempoParts.join(parts) == "-1-2-5")
    }

    /// Only a dash pasted into a field makes more than four parts. The rest
    /// stays in Top, so editing another part never drops it.
    @Test("Parts past the fourth stay in Top")
    func extraPartsStayInTop() {
        let parts = TempoParts.split("3-1-2-0-5")
        #expect(parts == ["3", "1", "2", "0-5"])
        #expect(TempoParts.join(parts) == "3-1-2-0-5")
    }
}
