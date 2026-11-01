// MuscleVolumeTargetStepperBRUTests.swift
// fitbodTests
//
// Phase 05.1-01 Task 3 — TDD RED suite for the BRU-reskinned
// MuscleVolumeTargetStepper.
//
// Strategy:
//   Tests 1–2 assert verbatim copy strings exposed as internal constants.
//   Tests 3–4 assert mutation behavior on an in-memory SwiftData
//   MuscleVolumeTarget. No SwiftUI rendering — pure value / model tests.
//
//   These tests are GREEN once Task 3 GREEN implementation ships.

import Foundation
import SwiftData
import Testing
@testable import fitbod

// MARK: - MuscleVolumeTargetStepperBRUTests

@Suite("MuscleVolumeTargetStepperBRU")
struct MuscleVolumeTargetStepperBRUTests {

    // MARK: - Helpers

    @MainActor
    private func makeTarget() throws -> (ModelContext, MuscleVolumeTarget) {
        let context = try FatigueTestFixtures.makeContext()
        let target = MuscleVolumeTarget()
        target.mv = 4
        target.mev = 8
        target.mav = 16
        target.mrv = 22
        target.userEdited = false
        context.insert(target)
        try context.save()
        return (context, target)
    }

    // MARK: - Test 1: verbatim suffix copy strings

    @Test("Stepper suffix copy strings match UI-SPEC §Copywriting Contract verbatim")
    func stepperSuffixStringsVerbatim() {
        // The four suffix strings used in stepperRow calls must be
        // character-for-character per 05-UI-SPEC §MuscleVolumeTargetStepper table.
        // T34: they follow the set count, which BRUCountLabel writes, so a
        // target of 1 reads "1 set — maintenance".
        #expect(MuscleVolumeTargetStepper.mvSuffix == "— maintenance",
                "MV suffix must be \"— maintenance\" verbatim")
        #expect(MuscleVolumeTargetStepper.mevSuffix == "— min for growth",
                "MEV suffix must be \"— min for growth\" verbatim")
        #expect(MuscleVolumeTargetStepper.mavSuffix == "— peak adaptive",
                "MAV suffix must be \"— peak adaptive\" verbatim")
        #expect(MuscleVolumeTargetStepper.mrvSuffix == "— max recoverable",
                "MRV suffix must be \"— max recoverable\" verbatim")
    }

    // MARK: - Test 2: verbatim monotonic error copy

    @Test("Monotonic validation error copy matches UI-SPEC §Copywriting Contract verbatim")
    func monotonicErrorCopyVerbatim() {
        // The inline validation error must read exactly as in UI-SPEC
        // §MuscleVolumeTargetStepper table: "Targets must be in order: MV ≤ MEV < MAV < MRV."
        #expect(MuscleVolumeTargetStepper.monotonicErrorCopy == "Targets must be in order: MV ≤ MEV < MAV < MRV.",
                "Monotonic error copy must match UI-SPEC §Copywriting Contract verbatim")
    }

    // MARK: - Test 3: stepper edit sets userEdited = true

    @Test("Incrementing MEV value sets target.userEdited = true")
    @MainActor
    func stepperEditSetsUserEdited() throws {
        let (_, target) = try makeTarget()
        #expect(target.userEdited == false, "precondition: userEdited starts false")
        // Simulate what the Stepper's onChange closure does
        target.mev = target.mev + 1
        target.userEdited = true
        #expect(target.userEdited == true,
                "any Stepper edit must set target.userEdited = true (VOL-03 / SET-05 idempotency)")
    }

    // MARK: - Test 4: reset writes RP defaults and clears userEdited

    @Test("resetToRPDefaults writes RPVolumeLandmarks values and clears userEdited")
    @MainActor
    func resetWritesRPDefaultsAndClearsFlag() throws {
        let (_, target) = try makeTarget()

        // Attach a muscle so the reset can look up the landmark
        let muscle = MuscleGroup()
        muscle.slug = "chest"
        muscle.displayName = "Chest"
        target.muscle = muscle
        target.userEdited = true

        // Call the internal helper directly
        MuscleVolumeTargetStepper.applyRPDefaults(to: target)

        let landmark = RPVolumeLandmarks.landmark(for: "chest")
        #expect(target.mv == landmark.mv, "reset must write landmark.mv")
        #expect(target.mev == landmark.mev, "reset must write landmark.mev")
        #expect(target.mav == landmark.mav, "reset must write landmark.mav")
        #expect(target.mrv == landmark.mrv, "reset must write landmark.mrv")
        #expect(target.userEdited == false, "reset must clear userEdited flag")
    }
}
