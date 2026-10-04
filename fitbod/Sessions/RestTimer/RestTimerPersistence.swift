//
//  RestTimerPersistence.swift
//  fitbod
//
//  Survives app termination for the rest timer. The engine already derives
//  every reading from an absolute moment (`startedAt + targetSeconds`), so
//  persisting that moment is all it takes for a relaunch — or a long
//  background stint where iOS evicts the process — to show the correct
//  remaining time instead of resetting.
//
//  Stored in UserDefaults (not SwiftData) on purpose: the timer is
//  ephemeral UI state, it must not require a schema migration, and
//  UserDefaults writes are handed to cfprefsd immediately, so they survive
//  even an abrupt kill right after a set is completed.
//

import Foundation

/// The persisted timer state. `deadline` is the single source of truth for
/// "when does rest end".
public struct RestTimerSnapshot: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var targetSeconds: Int
    public var exerciseName: String
    public var sessionID: UUID?

    public init(startedAt: Date, targetSeconds: Int, exerciseName: String, sessionID: UUID?) {
        self.startedAt = startedAt
        self.targetSeconds = targetSeconds
        self.exerciseName = exerciseName
        self.sessionID = sessionID
    }

    /// Absolute end of the rest period.
    public var deadline: Date {
        startedAt.addingTimeInterval(TimeInterval(targetSeconds))
    }
}

/// Storage seam for `RestTimerEngine`. Production uses UserDefaults; tests
/// use `InMemoryRestTimerStore` or a throwaway UserDefaults suite.
@MainActor
public protocol RestTimerPersisting: AnyObject {
    func load() -> RestTimerSnapshot?
    func save(_ snapshot: RestTimerSnapshot?)
}

@MainActor
public final class UserDefaultsRestTimerStore: RestTimerPersisting {
    public static let key = "rest-timer.snapshot.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> RestTimerSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(RestTimerSnapshot.self, from: data)
    }

    public func save(_ snapshot: RestTimerSnapshot?) {
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}

@MainActor
public final class InMemoryRestTimerStore: RestTimerPersisting {
    public var snapshot: RestTimerSnapshot?

    public init(snapshot: RestTimerSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() -> RestTimerSnapshot? { snapshot }

    public func save(_ snapshot: RestTimerSnapshot?) {
        self.snapshot = snapshot
    }
}

/// Scheduler used under `-ui-testing` (and previews): no permission
/// prompt, no pending requests.
@MainActor
public final class NoopNotificationScheduler: RestTimerNotificationScheduling {
    public init() {}
    public func schedule(in seconds: Int, exerciseName: String, identifier: String) {}
    public func cancel(identifier: String) {}
}
