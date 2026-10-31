// RoutineCreator.swift
// fitbod
//
// Creates a routine (UI term; code entity `Split`). Program and Today both
// open the same name step (`NewRoutineNameScreen`), and its SAVE is the only
// caller, so a routine exists only once the user has named it. Leaving the
// step creates nothing (tradeoffs.md "New routine flow").

import Foundation
import SwiftData

@MainActor
public enum RoutineCreator {

    /// Inserts and saves a routine named `name`, trimmed. Returns nil for a
    /// blank name, or if the save failed.
    public static func create(named name: String, context: ModelContext) -> Split? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let split = Split()
        context.insert(split)
        split.name = trimmed
        do {
            try context.save()
            return split
        } catch {
            context.delete(split)
            return nil
        }
    }
}
