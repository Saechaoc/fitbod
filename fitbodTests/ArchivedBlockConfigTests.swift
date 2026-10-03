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

// MARK: - write(from:endedAt:) tests (Task 1 — Phase 8 Plan 03)

import SwiftData

@MainActor
@Suite("ArchivedBlockConfig.write", .serialized)
struct ArchivedBlockConfigWriteTests {

    private func makeContext() throws -> ModelContext {
        let container = try FitbodModelContainer.make(inMemory: true)
        return ModelContext(container)
    }

    /// Builds a Block with a split, slot, session template, exercise, and phase.
    private func makeFullBlock(_ ctx: ModelContext) throws -> Block {
        let exercise = Exercise()
        ctx.insert(exercise)
        exercise.name = "Squat"

        let template = SessionTemplate()
        ctx.insert(template)
        template.name = "Day A"
        template.intentRaw = "strength"
        template.progressionKindRaw = "double"

        let set = SessionExerciseTemplate()
        ctx.insert(set)
        set.sessionTemplate = template
        set.exercise = exercise
        set.orderIndex = 0
        set.targetSets = 3
        set.targetRepsLow = 5
        set.targetRepsHigh = 8
        set.targetRPE = 8.0
        set.prescribedRestSeconds = 180
        // WR-03: author exercise-level notes + warmup flag so the mirror is testable.
        set.notes = "Pause at chest"
        set.generateWarmups = true

        let slot = SplitSessionSlot()
        ctx.insert(slot)
        slot.position = 0
        slot.sessionTemplate = template

        let split = Split()
        ctx.insert(split)
        split.name = "PPL"
        slot.split = split

        let phase = BlockPhase()
        ctx.insert(phase)
        phase.orderIndex = 0
        phase.nameRaw = "accumulation"
        phase.weeks = 4
        phase.volumeMultiplier = 1.0
        phase.intensityMultiplier = 1.0
        // WR-02: author phase-level notes so the mirror is testable.
        phase.notes = "Build base volume"

        let block = Block()
        ctx.insert(block)
        block.name = "Strength Block"
        block.startDate = Date(timeIntervalSince1970: 0)
        block.schedulingModeRaw = "rotation"
        block.trainingDays = [2, 4, 6]
        block.split = split
        phase.block = block

        try ctx.save()
        return block
    }

    @Test("write produces a non-empty JSON string")
    func writeProducesNonEmptyString() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        let endedAt = Date(timeIntervalSince1970: 3600)
        let json = try ArchivedBlockConfig.write(from: block, endedAt: endedAt)
        #expect(!json.isEmpty)
    }

    @Test("write round-trips to ArchivedBlockConfig with v == 1")
    func writeRoundTripsToV1() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        let endedAt = Date(timeIntervalSince1970: 3600)
        let json = try ArchivedBlockConfig.write(from: block, endedAt: endedAt)
        let data = Data(json.utf8)
        let decoded = try ArchivedBlockConfig.decode(from: data)
        #expect(decoded.v == 1)
        #expect(decoded.blockName == "Strength Block")
    }

    @Test("write mirrors phases in orderIndex order")
    func writeMirrorsPhases() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        // Add a second phase with higher orderIndex
        let phase2 = BlockPhase()
        ctx.insert(phase2)
        phase2.orderIndex = 1
        phase2.nameRaw = "deload"
        phase2.weeks = 1
        phase2.volumeMultiplier = 0.6
        phase2.intensityMultiplier = 0.8
        phase2.block = block
        try ctx.save()

        let json = try ArchivedBlockConfig.write(from: block, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        #expect(decoded.phases.count == 2)
        #expect(decoded.phases[0].kind == "accumulation")
        #expect(decoded.phases[1].kind == "deload")
    }

    @Test("write mirrors slot exercises with intentRaw/progressionKindRaw from sessionTemplate")
    func writeMirrorsExercisesWithSessionTemplateIntent() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        let json = try ArchivedBlockConfig.write(from: block, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        #expect(decoded.split.slots.count == 1)
        let exercise = decoded.split.slots[0].exercises[0]
        #expect(exercise.intentRaw == "strength")
        #expect(exercise.progressionKindRaw == "double")
        #expect(exercise.exerciseName == "Squat")
    }

    @Test("write uses 'Slot N' fallback when sessionTemplate name is empty")
    func writeUsesSlotFallbackWhenNameEmpty() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        // Clear the template name to trigger fallback
        if let slot = block.split?.slots?.first {
            slot.sessionTemplate?.name = ""
        }
        try ctx.save()

        let json = try ArchivedBlockConfig.write(from: block, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        #expect(decoded.split.slots[0].sessionName == "Slot 1")
    }

    @Test("write mirrors BlockPhase.notes — WR-02, full phase field mirror (spec §6)")
    func writeMirrorsPhaseNotes() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        let json = try ArchivedBlockConfig.write(from: block, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        #expect(decoded.phases[0].notes == "Build base volume",
            "BlockPhase.notes must be mirrored into the archive, not dropped")
    }

    @Test("write mirrors exercise notes + generateWarmups — WR-03 (spec §6)")
    func writeMirrorsExerciseNotesAndWarmupFlag() throws {
        let ctx = try makeContext()
        let block = try makeFullBlock(ctx)
        let json = try ArchivedBlockConfig.write(from: block, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        let exercise = decoded.split.slots[0].exercises[0]
        #expect(exercise.notes == "Pause at chest",
            "SessionExerciseTemplate.notes must be mirrored, not dropped")
        #expect(exercise.generateWarmups == true,
            "generateWarmups must mirror the template flag, not be hardcoded false")
    }

    @Test("write uses 'strength'/'double' fallback when sessionTemplate is nil")
    func writeUsesFallbackWhenTemplateNil() throws {
        let ctx = try makeContext()

        let split2 = Split()
        ctx.insert(split2)
        split2.name = "No-template split"

        let slot2 = SplitSessionSlot()
        ctx.insert(slot2)
        slot2.position = 0
        slot2.split = split2
        // sessionTemplate is nil

        let block2 = Block()
        ctx.insert(block2)
        block2.name = "Sparse"
        block2.startDate = .now
        block2.schedulingModeRaw = "rotation"
        block2.split = split2
        try ctx.save()

        let json = try ArchivedBlockConfig.write(from: block2, endedAt: .now)
        let decoded = try ArchivedBlockConfig.decode(from: Data(json.utf8))
        #expect(decoded.split.slots[0].sessionName == "Slot 1")
    }
}
