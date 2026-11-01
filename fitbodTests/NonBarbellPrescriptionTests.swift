import Foundation
import SwiftData
import Testing
@testable import fitbod

// SwiftData fixtures and SessionFactory run on the model's main actor.
@MainActor
@Suite("NonBarbellPrescription")
struct NonBarbellPrescriptionTests {
    @Test("Cable 25 lb prescription has no bar or plates")
    func cableUsesIncrementFromZero() throws {
        let (context, exercise, session, settings) = try fixture(equipment: .cable)
        let result = prescribe(context, exercise, session, settings)
        #expect(result.barWeight == 0)
        #expect(result.plates.isEmpty)
        #expect(result.weight == 25)
    }

    @Test("Machine has no empty-bar warm-up input")
    func machineHasNoEmptyBar() throws {
        let (context, exercise, session, settings) = try fixture(equipment: .machine)
        let result = prescribe(context, exercise, session, settings)
        #expect(result.barWeight == 0)
        #expect(result.plates.isEmpty)
        let row = SessionExercise()
        context.insert(row)
        row.exercise = exercise
        row.session = session
        #expect(SessionFactory.warmupRamp(for: row, prescription: result,
            deloadActive: false, warmupConfig: nil).isEmpty)
    }

    @Test("Every non-plate equipment uses the exercise increment", arguments: [
        Equipment.machine, .cable, .bands, .bodyweight, .weightedBodyweight, .kettlebell, .other
    ])
    func nonPlateEquipmentUsesExerciseIncrement(equipment: Equipment) throws {
        let (context, exercise, session, settings) = try fixture(
            equipment: equipment, weight: 29.9, increment: 3)
        settings.defaultIncrementKg = 5
        let result = prescribe(context, exercise, session, settings,
            strategy: DoubleProgressionStrategy(roundingIncrement: 7))
        #expect(result.weight == 27)
        #expect(result.barWeight == 0)
        #expect(result.plates.isEmpty)
    }

    @Test("Default increment rounds stored weights without converting units", arguments: [WeightUnit.lb, .kg])
    func defaultIncrementDoesNotConvert(unit: WeightUnit) throws {
        let (context, exercise, session, settings) = try fixture(
            equipment: .cable, weight: 29.9, increment: nil)
        settings.weightUnit = .lb
        settings.defaultIncrementKg = 5
        exercise.unitOverride = unit
        let result = prescribe(context, exercise, session, settings)
        #expect(result.weight == 25)
        #expect(result.barWeight == 0)
        #expect(result.plates.isEmpty)
    }

    @Test("A non-plate exercise's bar override anchors its increment grid")
    func nonPlateBarOverrideStillApplies() throws {
        let (context, exercise, session, settings) = try fixture(
            equipment: .machine, weight: 29.9, increment: 5)
        exercise.barWeightOverride = 7
        let result = prescribe(context, exercise, session, settings)
        #expect(result.weight == 27)
        #expect(result.barWeight == 7)
        #expect(result.plates.isEmpty)
    }

    @Test("Plate equipment keeps its finite inventory and clears increment mode",
          arguments: [Equipment.barbell, .dumbbell])
    func plateEquipmentKeepsInventory(equipment: Equipment) throws {
        let (context, exercise, session, settings) = try fixture(equipment: equipment, weight: 101)
        let inventory = try #require(context.fetch(FetchDescriptor<PlateInventory>()).first)
        inventory.availablePlates = [PlateSpec(weight: 5, countPerSide: 1)]
        try context.save()
        let result = prescribe(context, exercise, session, settings,
            strategy: DoubleProgressionStrategy(roundingIncrement: 7))
        let bar = equipment == .barbell ? 45.0 : 0.0
        #expect(result.weight == bar + 10)
        #expect(result.barWeight == bar)
        #expect(result.plates.count == 1)
        #expect(result.plates.first?.weight == 5)
    }

    private func prescribe(_ context: ModelContext, _ exercise: Exercise,
                           _ session: Session, _ settings: UserSettings,
                           strategy: any ProgressionStrategy = DoubleProgressionStrategy()) -> SessionFactory.ExercisePrescription {
        SessionFactory.prescription(for: exercise, targetRepsLow: 10, targetRepsHigh: 15,
            targetRPE: nil, in: session, strategy: strategy,
            userSettings: settings, context: context)
    }

    private func fixture(equipment: Equipment, weight: Double = 25,
                         increment: Double? = 2.5) throws -> (ModelContext, Exercise, Session, UserSettings) {
        let name = "T141-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let container = try FitbodModelContainer.make(inMemory: true, defaults: defaults)
        let context = ModelContext(container)
        let exercise = Exercise.previewSample(name: "Prescription fixture", equipment: equipment,
            mechanic: .compound, primaryMuscleSlugs: [])
        context.insert(exercise)
        exercise.smallestIncrement = increment
        let settings = UserSettings()
        context.insert(settings)
        settings.weightUnit = .lb
        let inventory = PlateInventory()
        context.insert(inventory)
        inventory.equipmentKind = equipment == .dumbbell ? .dumbbell : .barbell
        inventory.barWeight = equipment == .dumbbell ? 0 : 45
        inventory.availablePlates = PlateInventoryDefaults.make(for: .barbell, unitSystem: .lb)
        let prior = Session()
        context.insert(prior)
        prior.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        prior.completedAt = prior.startedAt.addingTimeInterval(100)
        prior.intentRaw = Intent.hypertrophy.rawValue
        let row = SessionExercise()
        context.insert(row)
        row.session = prior
        row.exercise = exercise
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = row
        set.weight = weight
        set.reps = 12
        set.isComplete = true
        set.completedAt = prior.completedAt!
        let session = Session()
        context.insert(session)
        session.startedAt = prior.startedAt.addingTimeInterval(86400)
        session.intentRaw = prior.intentRaw
        try context.save()
        return (context, exercise, session, settings)
    }
}
