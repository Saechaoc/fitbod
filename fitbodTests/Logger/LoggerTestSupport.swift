//
//  LoggerTestSupport.swift
//  fitbodTests
//
//  Shared fixtures for the M1 logger suites: an in-memory container on
//  the production schema plus builders for templates and sessions.
//

import Foundation
import SwiftData
@testable import fitbod

@MainActor
enum LoggerFixtures {

    static func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    static func exercise(_ name: String, in ctx: ModelContext) -> Exercise {
        let ex = Exercise.previewSample(name: name, equipment: .barbell, mechanic: .compound)
        ctx.insert(ex)
        return ex
    }

    /// A template with one prescription row per exercise.
    static func template(
        _ name: String,
        exercises: [Exercise],
        sets: Int = 3,
        repsLow: Int = 5,
        repsHigh: Int = 8,
        rest: Int = 180,
        in ctx: ModelContext
    ) throws -> SessionTemplate {
        let template = SessionTemplate()
        ctx.insert(template)
        template.name = name
        template.intentRaw = Intent.strength.rawValue
        for (i, ex) in exercises.enumerated() {
            let row = SessionExerciseTemplate()
            ctx.insert(row)
            row.sessionTemplate = template
            row.exercise = ex
            row.orderIndex = i
            row.targetSets = sets
            row.targetRepsLow = repsLow
            row.targetRepsHigh = repsHigh
            row.prescribedRestSeconds = rest
        }
        try ctx.save()
        return template
    }

    /// A session with one exercise and the given sets. `completedAt` nil
    /// leaves the session in progress.
    @discardableResult
    static func session(
        exercise: Exercise,
        startedAt: Date,
        completedAt: Date?,
        sets: [(weight: Double, reps: Int, complete: Bool)],
        in ctx: ModelContext
    ) throws -> Session {
        let session = Session()
        ctx.insert(session)
        session.startedAt = startedAt
        session.completedAt = completedAt
        session.intentRaw = Intent.strength.rawValue
        let se = SessionExercise()
        ctx.insert(se)
        se.session = session
        se.exercise = exercise
        se.exerciseNameSnapshot = exercise.name
        for (i, s) in sets.enumerated() {
            let entry = SetEntry()
            ctx.insert(entry)
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = s.weight
            entry.reps = s.reps
            entry.isComplete = s.complete
            entry.completedAt = startedAt.addingTimeInterval(Double(i) * 120)
        }
        try ctx.save()
        return session
    }
}
