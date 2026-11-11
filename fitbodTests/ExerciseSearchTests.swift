//
//  ExerciseSearchTests.swift
//  fitbodTests
//
//  The Library's word-prefix search (RM-022): how a query is read, what a
//  row is found by, and the order results come in.
//

import Testing
@testable import fitbod

@Suite("ExerciseSearch")
struct ExerciseSearchTests {

    private typealias Row = ExerciseSearch.Row

    private func names(_ query: String, in rows: [Row]) -> [String] {
        ExerciseSearch.results(query, in: rows) { $0 }.map(\.item.name)
    }

    @Test("Punctuation, case and accents do not matter, and joined words find split ones")
    func reading() {
        let pullUp = Row(name: "Pull-Up")
        for query in ["pull up", "PULL-UP", "pullup", "pull-ups", "Pullups"] {
            #expect(ExerciseSearch.hit(query, in: pullUp) != nil, "\(query)")
        }
        #expect(ExerciseSearch.hit("pull down", in: Row(name: "Wide-Grip Lat Pulldown")) != nil)
        #expect(ExerciseSearch.hit("cafe", in: Row(name: "Café Press")) != nil)
    }

    @Test("Every query word must start one of the row's words, in any order")
    func wordOrder() {
        let row = Row(name: "Triceps Extension (Cable)")
        #expect(ExerciseSearch.hit("cable tricep ext", in: row) != nil)
        #expect(ExerciseSearch.hit("ext triceps", in: row) != nil)
        #expect(ExerciseSearch.hit("tension", in: row) == nil, "The middle of a word does not match")
        #expect(ExerciseSearch.hit("cable fly", in: row) == nil)
    }

    @Test("Plurals, short forms and the equipment's words find a row")
    func formsAndEquipment() {
        let curl = Row(name: "Hammer Curl", equipment: "Dumbbell")
        #expect(ExerciseSearch.hit("hammer curls", in: curl) != nil)
        #expect(ExerciseSearch.hit("db hammer", in: curl) != nil)
        #expect(ExerciseSearch.hit("dumbbell curl", in: curl) != nil)
        #expect(ExerciseSearch.hit("bb curl", in: curl) == nil)
        #expect(ExerciseSearch.hit("presses", in: Row(name: "Bench Press")) != nil)
    }

    @Test("A row found through an alias shows that alias; a row its own words find shows none")
    func aliases() {
        let climber = Row(name: "Stair Climber", aliases: ["stairmaster", "stair stepper"])
        #expect(ExerciseSearch.hit("stairmaster", in: climber) == .init(rank: .whole, alias: "stairmaster"))
        #expect(ExerciseSearch.hit("stair master", in: climber) == .init(rank: .whole, alias: "stairmaster"))
        #expect(ExerciseSearch.hit("stepper", in: climber) == .init(rank: .other, alias: "stair stepper"))
        #expect(ExerciseSearch.hit("stair", in: climber) == .init(rank: .nameStart, alias: nil))
        let run = Row(name: "Treadmill Run", aliases: ["treadmill", "running"])
        #expect(ExerciseSearch.hit("treadmill", in: run) == .init(rank: .whole, alias: nil))
    }

    @Test("A whole name or alias comes first, then names that start with the query or its first word, then the rest by name")
    func ordering() {
        let rows = [
            Row(name: "Smith Machine Bench Press"),
            Row(name: "Bench Press"),
            Row(name: "Bench Dips"),
            Row(name: "Barbell Bench Press - Medium Grip", aliases: ["flat bench"]),
            Row(name: "Incline Bench Press"),
            Row(name: "Leg Press"),
        ]
        #expect(names("bench press", in: rows) == [
            "Bench Press",
            "Barbell Bench Press - Medium Grip",
            "Incline Bench Press",
            "Smith Machine Bench Press",
        ])
        #expect(names("flat bench", in: rows).first == "Barbell Bench Press - Medium Grip")
        #expect(names("bench", in: rows).prefix(2) == ["Bench Dips", "Bench Press"])
        #expect(names("", in: rows).count == rows.count)
        // A name typed without its hyphen is still the whole name.
        let sitUps = [Row(name: "3/4 Sit-Up"), Row(name: "Frog Sit-Ups"), Row(name: "Sit-Up")]
        #expect(names("situp", in: sitUps).first == "Sit-Up")
        let presses = [Row(name: "Hammer Grip Incline DB Bench Press"), Row(name: "Incline Dumbbell Press")]
        #expect(names("incline press db", in: presses) == ["Incline Dumbbell Press", "Hammer Grip Incline DB Bench Press"])
        #expect(ExerciseSearch.hit("db curl", in: Row(name: "Dumbbell Bicep Curl"))?.rank == .nameStart)
    }
}
