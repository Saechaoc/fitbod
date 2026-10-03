// RoutineCreator.swift
// fitbod
//
// Creates a routine (UI term; code entity `Split`). Program and Today both
// create routines the same way: insert an "Untitled routine" immediately and
// open its detail screen, where it is renamed and filled with sessions.
// Creating the row first means a half-built routine is always visible in
// Program's ROUTINES list instead of being lost.

import Foundation
import SwiftData

@MainActor
public enum RoutineCreator {

    /// Inserts and saves a new routine. Returns nil if the save failed.
    public static func create(context: ModelContext) -> Split? {
        let existing = (try? context.fetch(FetchDescriptor<Split>()))?.map(\.name) ?? []
        let split = Split()
        context.insert(split)
        split.name = nextUntitledName(existing: existing)
        do {
            try context.save()
            return split
        } catch {
            context.delete(split)
            return nil
        }
    }

    /// "Untitled routine", then "Untitled routine 2", "Untitled routine 3"…
    /// skipping names already taken.
    public static func nextUntitledName(existing: [String]) -> String {
        let base = "Untitled routine"
        let taken = Set(existing)
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
