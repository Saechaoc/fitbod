//
//  ArchivedBlockConfigTests.swift
//  fitbodTests
//
//  RED scaffold: verifies ArchivedBlockConfig Codable DTO behaviour before
//  the type is created. These tests will fail until ArchivedBlockConfig.swift
//  exists.
//
//  Phase 7 Plan 01 (07-01) — Task 2 TDD RED.
//

import Foundation
import Testing
@testable import fitbod

@Suite("ArchivedBlockConfig")
struct ArchivedBlockConfigTests {

    // MARK: - Helpers

    private func makeConfig(startedAt: Date = Date(timeIntervalSince1970: 0),
                             endedAt: Date = Date(timeIntervalSince1970: 3600)) -> ArchivedBlockConfig {
        let exercise = ArchivedExerciseDTO(
            exerciseID: UUID(),
            exerciseName: "Squat",
            orderIndex: 0,
            targetSets: 3,
            targetRepsLow: 5,
            targetRepsHigh: 8,
            targetRPE: 8.0,
            targetRIR: nil,
            prescribedRestSeconds: 180,
            tempo: nil,
            notes: nil,
            intentRaw: "strength",
            progressionKindRaw: "double",
            generateWarmups: true,
            tracksTempo: false,
            tracksPartialReps: false
        )
        let slot = ArchivedSlotDTO(
            position: 0,
            sessionName: "Day A",
            exercises: [exercise]
        )
        let split = ArchivedSplitDTO(name: "PPL", slots: [slot])
        let phase = ArchivedPhaseDTO(
            kind: "accumulation",
            weeks: 4,
            volumeMultiplier: 1.0,
            intensityMultiplier: 1.0,
            notes: nil
        )
        return ArchivedBlockConfig(
            blockName: "Strength Block",
            startedAt: startedAt,
            endedAt: endedAt,
            mode: "rotation",
            trainingDays: [2, 4, 6],
            phases: [phase],
            split: split
        )
    }

    // MARK: - v field defaults to 1

    @Test("v field defaults to 1 when not supplied")
    func vDefaultsToOne() {
        let config = makeConfig()
        #expect(config.v == 1)
    }

    // MARK: - Round-trip

    @Test("encode then decode round-trips equal")
    func roundTrip() throws {
        let config = makeConfig()
        let data = try config.encoded()
        let decoded = try ArchivedBlockConfig.decode(from: data)
        #expect(config == decoded)
    }

    // MARK: - ISO-8601 date round-trip

    @Test("Date fields encode and decode via iso8601")
    func iso8601DateRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let config = makeConfig(startedAt: fixedDate, endedAt: fixedDate.addingTimeInterval(3600))
        let data = try config.encoded()

        // Verify the raw JSON contains an ISO-8601 string (not a double)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let startedAtValue = json["startedAt"] as? String
        #expect(startedAtValue != nil)
        #expect(startedAtValue?.contains("T") == true)

        let decoded = try ArchivedBlockConfig.decode(from: data)
        // Dates survive a round-trip within 1-second precision (ISO-8601 seconds)
        #expect(abs(decoded.startedAt.timeIntervalSince(fixedDate)) < 1.0)
    }

    // MARK: - Nested DTO structure

    @Test("phases array is preserved through round-trip")
    func phasesPreserved() throws {
        let config = makeConfig()
        let decoded = try ArchivedBlockConfig.decode(from: try config.encoded())
        #expect(decoded.phases.count == 1)
        #expect(decoded.phases[0].kind == "accumulation")
        #expect(decoded.phases[0].weeks == 4)
    }

    @Test("split slots are preserved in order")
    func splitSlotsPreserved() throws {
        let config = makeConfig()
        let decoded = try ArchivedBlockConfig.decode(from: try config.encoded())
        #expect(decoded.split.slots.count == 1)
        #expect(decoded.split.slots[0].position == 0)
        #expect(decoded.split.slots[0].sessionName == "Day A")
    }

    @Test("exercises inside slots survive round-trip")
    func exercisesInSlotsPreserved() throws {
        let config = makeConfig()
        let decoded = try ArchivedBlockConfig.decode(from: try config.encoded())
        let ex = decoded.split.slots[0].exercises[0]
        #expect(ex.exerciseName == "Squat")
        #expect(ex.targetSets == 3)
        #expect(ex.intentRaw == "strength")
    }

    // MARK: - Decode failure on malformed JSON

    @Test("decode throws on malformed JSON — no live-template fallback")
    func decodeThrowsOnBadJSON() {
        let garbage = Data("not valid json at all".utf8)
        #expect(throws: (any Error).self) {
            try ArchivedBlockConfig.decode(from: garbage)
        }
    }

    @Test("decode throws on wrong-type JSON — no live-template fallback")
    func decodeThrowsOnWrongType() {
        let wrongType = Data("[]".utf8)
        #expect(throws: (any Error).self) {
            try ArchivedBlockConfig.decode(from: wrongType)
        }
    }
}
