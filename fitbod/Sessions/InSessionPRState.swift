//
//  InSessionPRState.swift
//  fitbod
//
//  Wave-4 plan 06-07 — @Observable session-scoped PR detector cache
//  (CONTEXT D-14..D-16). Owned by `SessionLoggerView` as `@State`;
//  drives the `.safeAreaInset(edge: .top)` banner mount per RESEARCH
//  Pattern 3.
//
//  State machine (D-15 + D-16):
//
//    init  → prTable empty, currentBanner == nil
//    seed  → SessionFactory.seedPRTable populates prTable at session
//            start via one batched fetch per RESEARCH Pitfall 6
//    save  → observeSave(set:) runs PRDetector.check against the live
//            table:
//              - PR hit(s): mutates prTable, sets currentBanner to a
//                stacked content value in canonical PRKind.allCases
//                order (weight → reps → volume → e1RM), fires
//                UINotificationFeedbackGenerator(.success), schedules a
//                5s dismiss Task
//              - No PR hit + currentBanner present: clears currentBanner
//                ("next save with no PRs replaces prior banner")
//    dismiss → user tapped capsule → currentBanner = nil + cancel task
//
//  Tap-to-dismiss + 5s auto-dismiss + next-save-clear are all
//  CONTEXT D-15 requirements.
//
//  CONTEXT D-17 reminder: `wasManualOverride` does NOT suppress PR
//  detection here — PRDetector.check is the gatekeeper, and it does
//  not filter on that field. An honest higher-weight set is a real
//  PR regardless of how the user entered the weight.
//
//  [CITED: CONTEXT D-14/D-15/D-16/D-17/D-35 + RESEARCH Pattern 3 +
//   Pitfall 6]
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Per-banner content — the value the SwiftUI capsule renders. Canonical
/// `PRKind` ordering is enforced at construction time so the capsule
/// chips read weight → reps → volume → e1RM regardless of detection
/// arrival order.
public struct InSessionPRBannerContent: Sendable, Equatable {
    public let kinds: [PRKind]
    public let weight: Double
    public let reps: Int
    /// Log-time exercise name; empty when the set has no exercise.
    public let exerciseName: String
    /// The exercise's own unit, if it has one. The banner falls back to
    /// the app-wide unit from the environment.
    public let unitOverride: WeightUnit?

    public init(
        kinds: [PRKind],
        weight: Double,
        reps: Int,
        exerciseName: String = "",
        unitOverride: WeightUnit? = nil
    ) {
        self.kinds = kinds
        self.weight = weight
        self.reps = reps
        self.exerciseName = exerciseName
        self.unitOverride = unitOverride
    }
}

/// `@Observable` session-scoped PR detector cache. Owned by
/// `SessionLoggerView` via `@State`; the inner `InSessionPRBanner`
/// reads `currentBanner` through plain property access.
@Observable
public final class InSessionPRState {
    public var prTable: PRTable
    public var currentBanner: InSessionPRBannerContent?

    /// 5s auto-dismiss task — cancelled when a fresh banner replaces
    /// the prior one or the user taps the capsule.
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    public init(prTable: PRTable = PRTable()) {
        self.prTable = prTable
    }

    /// Called from `SessionLoggerView.commitSet` after a working
    /// `SetEntry` is committed. Mutates `prTable` in place when new
    /// PRs hit; updates `currentBanner` to drive the `.safeAreaInset`
    /// render.
    @MainActor
    public func observeSave(set: SetEntry) {
        let hits = PRDetector.check(set: set, against: &prTable)
        if !hits.isEmpty {
            // Canonical order weight → reps → volume → e1RM
            let ordered = PRKind.allCases.filter { hits.contains($0) }
            currentBanner = InSessionPRBannerContent(
                kinds: ordered,
                weight: set.weight,
                reps: set.reps,
                exerciseName: set.sessionExercise?.displayName ?? "",
                unitOverride: set.sessionExercise?.exercise?.unitOverride
            )
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            dismissTask?.cancel()
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                await MainActor.run {
                    self?.currentBanner = nil
                }
            }
        } else if currentBanner != nil {
            // D-15 "next save with no PRs replaces prior banner" — clear.
            currentBanner = nil
            dismissTask?.cancel()
        }
    }

    @MainActor
    public func dismiss() {
        currentBanner = nil
        dismissTask?.cancel()
    }
}
