//
//  RestTimerStore.swift
//  fitbod
//
//  Persistence for the running rest timer, so a rest period survives the
//  logger closing, the app being backgrounded, and the app being killed.
//
//  The stored value is a deadline (`endsAt`), not a ticking counter: on
//  restore the engine compares it with the clock and either resumes the
//  countdown from the remaining time or reports the rest as finished.
//
//  Timer state is deliberately NOT a SwiftData field. It is short-lived UI
//  state, it changes on every +/-15s tap, and it must never ride along in
//  backups or exports. UserDefaults keyed by session id is the whole store.
//

import Foundation

/// One persisted rest period. `endsAt` is the source of truth;
/// `startedAt` + `targetSeconds` are kept so the progress arc and the
/// Live Activity can render the same proportion after a restore.
public struct RestTimerSnapshot: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var endsAt: Date
    public var targetSeconds: Int
    public var exerciseName: String

    public init(startedAt: Date, endsAt: Date, targetSeconds: Int, exerciseName: String) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.targetSeconds = targetSeconds
        self.exerciseName = exerciseName
    }
}

/// Storage seam for `RestTimerEngine`. Production uses
/// `UserDefaultsRestTimerStore`; tests and previews use
/// `InMemoryRestTimerStore`, and can share one instance between two
/// engines to simulate an app relaunch.
@MainActor
public protocol RestTimerStore: AnyObject {
    func load(sessionID: UUID) -> RestTimerSnapshot?
    func save(_ snapshot: RestTimerSnapshot, sessionID: UUID)
    func clear(sessionID: UUID)
}

/// UserDefaults-backed store. One JSON blob per session id.
@MainActor
public final class UserDefaultsRestTimerStore: RestTimerStore {
    private let defaults: UserDefaults
    private static let keyPrefix = "restTimer.deadline."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load(sessionID: UUID) -> RestTimerSnapshot? {
        guard let data = defaults.data(forKey: Self.key(sessionID)) else { return nil }
        return try? JSONDecoder().decode(RestTimerSnapshot.self, from: data)
    }

    public func save(_ snapshot: RestTimerSnapshot, sessionID: UUID) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key(sessionID))
    }

    public func clear(sessionID: UUID) {
        defaults.removeObject(forKey: Self.key(sessionID))
    }

    private static func key(_ sessionID: UUID) -> String {
        keyPrefix + sessionID.uuidString
    }
}

/// In-memory store for unit tests and previews.
@MainActor
public final class InMemoryRestTimerStore: RestTimerStore {
    public private(set) var snapshots: [UUID: RestTimerSnapshot] = [:]

    public init() {}

    public func load(sessionID: UUID) -> RestTimerSnapshot? { snapshots[sessionID] }
    public func save(_ snapshot: RestTimerSnapshot, sessionID: UUID) { snapshots[sessionID] = snapshot }
    public func clear(sessionID: UUID) { snapshots[sessionID] = nil }
}
