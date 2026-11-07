// HistoryEdits.swift
// fitbod
//
// Counts the History corrections saved since launch. Views that cache what
// they read from finished workouts (Today's and Progress's empty-workout
// ids, History's records and counts, a workout's summary) watch `version`
// and read again after a correction. The Edit workout screen bumps it after
// a save or a delete. RootView puts one in the environment.

import Observation

@MainActor
@Observable
public final class HistoryEdits {
    public private(set) var version = 0

    public init() {}

    public func recordSave() {
        version += 1
    }
}
