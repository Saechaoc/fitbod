# Stack Research Summary

**Domain:** Personal iOS bodybuilding / weight-training tracker
**Researched:** 2026-05-10 · **Full deep-dive:** docs/STACK-RESEARCH.md

## Decision

Swift 6 (strict concurrency) · SwiftUI · SwiftData (local-only) · iOS 26.4 target
Swift Charts for all data charts; Canvas for the muscle heatmap body silhouette
Swift Testing for unit tests; XCTest for UI tests only (Apple-confirmed gap)
Exercise catalog: vendored free-exercise-db JSON (public domain, ~800 exercises), seeded on first launch, strength/powerlifting/olympic/strongman categories only

No third-party persistence, charting, state management, Combine wrappers, or DI framework.

## Standing Prohibitions

See the Conventions section of CLAUDE.md for the full list. Short form:
- `@Observable` only — no `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`
- `@Query` directly in views — never wrapped in a view model
- One `NavigationStack` per tab — never wrap `TabView` in a `NavigationStack`
- No CloudKit, HealthKit, Core Data, Realm, DGCharts, Rx

## Full Rationale, Alternatives, Sources, Install

See docs/STACK-RESEARCH.md
