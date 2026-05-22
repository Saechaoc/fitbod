//
//  WarmupConfig.swift
//  fitbod
//
//  Per-routine-exercise warm-up override configuration. Stored as a
//  JSON-encoded `Data?` field (`warmupOverrideData`) on `RoutineExercise`
//  via the computed `warmupOverride: WarmupConfig?` accessor.
//
//  Fields are `var` (not `let`) because `SessionFactory` in plan 03-08
//  mutates `skipNextSession` to reset it to false after consuming the
//  skip signal at session-start.
//
//  Nil `warmupOverrideData` → no override → use default auto-warm-up
//  behavior (RESEARCH § Pitfall 5). A non-nil WarmupConfig with
//  `enabled = true` and `skipNextSession = false` is the "confirmed
//  default" state after the user has opened and closed the editor without
//  disabling warm-ups.
//

import Foundation

public struct WarmupConfig: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var skipNextSession: Bool

    public init(enabled: Bool = true, skipNextSession: Bool = false) {
        self.enabled = enabled
        self.skipNextSession = skipNextSession
    }
}
