//
//  LibraryLinesTests.swift
//  fitbodTests
//
//  The Library's browse lines (RM-022): two or more rows of a family fold
//  into one line, other rows stand alone, and lines sort and section by
//  title.
//

import Testing
@testable import fitbod

@Suite("Library lines")
struct LibraryLinesTests {

    private func exercise(_ name: String, family: String? = nil, variant: String? = nil, isCustom: Bool = false) -> Exercise {
        let exercise = Exercise(
            name: name, canonicalName: name.lowercased(),
            equipmentRaw: Equipment.barbell.rawValue, mechanicRaw: Mechanic.compound.rawValue,
            isCustom: isCustom
        )
        exercise.familyName = family
        exercise.variantLabel = variant
        return exercise
    }

    @Test("Two or more rows of a family fold into one line; a lone member and a row without a family stand alone")
    func familiesFold() throws {
        let lines = LibraryLines.sections([
            exercise("Bench Press (Dumbbell)", family: "Bench Press", variant: "Dumbbell"),
            exercise("Leg Extension", family: "Leg Extension"),
            exercise("Bench Press (Barbell)", family: "Bench Press", variant: "Barbell"),
            exercise("Landmine Press"),
        ]).flatMap(\.lines)

        #expect(lines.map(\.title) == ["Bench Press", "Landmine Press", "Leg Extension"])
        guard case .family(_, let variants) = lines[0] else {
            Issue.record("Bench Press must fold into a family line")
            return
        }
        #expect(variants.map(LibraryLines.variantTitle) == ["Barbell", "Dumbbell"])
        guard case .exercise(let lone) = lines[2] else {
            Issue.record("A family with one listed row shows the row itself")
            return
        }
        #expect(lone.name == "Leg Extension")
    }

    @Test("Sections run A to Z by title, then # for a title that starts with a digit")
    func sectionsByTitle() {
        let sections = LibraryLines.sections([
            exercise("3/4 Sit-Up"),
            exercise("Squat (Front)", family: "Squat", variant: "Front"),
            exercise("Arnold Press", family: "Overhead Press", variant: "Arnold Press"),
            exercise("Ab Wheel Rollout"),
            exercise("Squat (Back)", family: "Squat", variant: "Back"),
            exercise("Overhead Press (Barbell)", family: "Overhead Press", variant: "Barbell"),
        ])
        #expect(sections.map(\.letter) == ["A", "O", "S", "#"])
        #expect(sections.map { $0.lines.map(\.title) } == [["Ab Wheel Rollout"], ["Overhead Press"], ["Squat"], ["3/4 Sit-Up"]])
    }

    @Test("A family lists its standard version first, then each variant by title")
    func standardVersionFirst() throws {
        let line = try #require(LibraryLines.sections([
            exercise("Pull-Up (Weighted)", family: "Pull-Up", variant: "Weighted"),
            exercise("Pull-Up", family: "Pull-Up"),
            exercise("Pull-Up (Band-Assisted)", family: "Pull-Up", variant: "Band-Assisted"),
        ]).first?.lines.first)
        guard case .family(_, let variants) = line else {
            Issue.record("Pull-Up must fold into a family line")
            return
        }
        #expect(variants.map(LibraryLines.variantTitle) == ["Pull-Up", "Band-Assisted", "Weighted"])
    }

    @Test("A custom exercise sorts by its name among the variants, after the standard version")
    func customExercisesSortWithTheVariants() throws {
        let line = try #require(LibraryLines.sections([
            exercise("Pull-Up (Weighted)", family: "Pull-Up", variant: "Weighted"),
            exercise("Mixed-Grip Pull-Up", family: "Pull-Up", isCustom: true),
            exercise("Pull-Up", family: "Pull-Up"),
            exercise("Archer Pull-Up", family: "Pull-Up", isCustom: true),
            exercise("Pull-Up (Band-Assisted)", family: "Pull-Up", variant: "Band-Assisted"),
        ]).first?.lines.first)
        guard case .family(_, let variants) = line else {
            Issue.record("Pull-Up must fold into a family line")
            return
        }
        #expect(variants.map(LibraryLines.variantTitle) == ["Pull-Up", "Archer Pull-Up", "Band-Assisted", "Mixed-Grip Pull-Up", "Weighted"])
    }

    @Test("A custom exercise is never the standard version: with a variant label it sorts by the label, and named like its family it sorts after the standard row")
    func customExercisesAreNeverTheStandardVersion() throws {
        let line = try #require(LibraryLines.sections([
            exercise("Pull-Up (Weighted)", family: "Pull-Up", variant: "Weighted"),
            exercise("Pull-Up", family: "Pull-Up", isCustom: true),
            exercise("Pull-Up (Archer)", family: "Pull-Up", variant: "Archer", isCustom: true),
            exercise("Pull-Up", family: "Pull-Up"),
            exercise("Pull-Up (Band-Assisted)", family: "Pull-Up", variant: "Band-Assisted"),
        ]).first?.lines.first)
        guard case .family(_, let variants) = line else {
            Issue.record("Pull-Up must fold into a family line")
            return
        }
        #expect(variants.map(LibraryLines.variantTitle) == ["Pull-Up", "Archer", "Band-Assisted", "Pull-Up", "Weighted"])
        #expect(variants.map(\.isCustom) == [false, true, false, true, false])
    }

    @Test("A family with no standard version lists every row A to Z by its shown title, whatever its letter case")
    func noStandardVersionSortsAToZ() throws {
        let line = try #require(LibraryLines.sections([
            exercise("Pull-Up (Weighted)", family: "Pull-Up", variant: "Weighted"),
            exercise("archer pull-up", family: "Pull-Up", isCustom: true),
            exercise("Pull-Up (Band-Assisted)", family: "Pull-Up", variant: "Band-Assisted"),
        ]).first?.lines.first)
        guard case .family(_, let variants) = line else {
            Issue.record("Pull-Up must fold into a family line")
            return
        }
        // A case-sensitive sort would put "archer" after every capital.
        #expect(variants.map(LibraryLines.variantTitle) == ["archer pull-up", "Band-Assisted", "Weighted"])
    }
}
