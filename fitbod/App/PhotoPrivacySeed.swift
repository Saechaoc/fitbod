import Foundation
import SwiftData

enum PhotoPrivacySeed {
    @MainActor
    static func runIfRequested(in context: ModelContext) throws {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-fitbod-seed-unreadable-photo") else { return }
        let externalID = "photo-privacy-test"
        guard try context.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.externalID == externalID })) == 0 else { return }
        guard let chest = try context.fetch(FetchDescriptor<MuscleGroup>(predicate: #Predicate { $0.slug == "chest" })).first else { return }
        let exercise = Exercise(name: "Unreadable photo test", canonicalName: "unreadable photo test",
                                equipmentRaw: "barbell", mechanicRaw: "compound", isCustom: true)
        context.insert(exercise)
        exercise.externalID = externalID
        exercise.imageData = Data([1, 2, 3])
        exercise.primaryMuscleSlugsJoined = "|chest|"
        let stimulus = ExerciseMuscleStimulus()
        context.insert(stimulus)
        stimulus.exercise = exercise
        stimulus.muscle = chest
        try context.save()
        #endif
    }
}
