//
//  SeedState.swift
//  fitbod
//
//  Small `@Observable` state machine tracking the lifecycle of
//  `ExerciseLibraryImporter.seedIfNeeded()`. Owned by `RootView` and
//  flipped by the `.task` modifier on first appearance.
//
//  Phases:
//    - `.idle`    — initial state; the seed task has not yet started
//    - `.loading` — `seedIfNeeded` is in flight; RootView shows the
//                   "Preparing library…" splash
//    - `.ready`   — seed completed (or short-circuited on subsequent
//                   launches); the TabView renders
//    - `.failed`  — seed threw; RootView still transitions to the
//                   TabView (the seed error is non-fatal — `@Query`
//                   over the previously-seeded store still works on
//                   later launches; the error case is reserved for
//                   the catastrophic Alert deferred to Wave 4 polish
//                   per UI-SPEC.md § Error states)
//
//  The state is intentionally separate from a SwiftUI `@State` boolean
//  because it lets later phases reason about *why* the splash dismissed
//  (e.g. an analytics call on `.failed`) without splattering the
//  RootView with additional flags. The four-case enum gives every
//  future caller a typed surface to switch on.
//
//  Pattern source: Swift 5.9 `@Observable` macro + plan 03-01 execution
//  rules ("Manage seed state via a small `@Observable SeedState` type
//  with idle / loading / ready / failed cases").
//

import Foundation
import Observation

/// Lifecycle phase of the first-launch seed task.
public enum SeedPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed(message: String)
}

/// Observable wrapper around `SeedPhase` so SwiftUI views can read
/// `seedState.phase` reactively without an explicit `@Published` /
/// `ObservableObject` ceremony.
@Observable
public final class SeedState {
    public var phase: SeedPhase = .idle

    public init() {}
}
