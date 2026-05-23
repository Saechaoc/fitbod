//
//  IntentChip.swift
//  fitbod
//
//  Phase 3.1 plan 06 (PIVOT-04 / D-11) — shared SwiftUI component extracted
//  from Phase 2's private `intentChip` view on `RoutineExerciseCard` (which
//  Plan 04 already stripped from `RoutineExerciseCard` since intent is now
//  session-level, not per-exercise — see UI-SPEC § RoutineExerciseCard header
//  intent chip REMOVED). The chip's accent-capsule styling is preserved
//  verbatim; only the surface where it renders shifts from per-exercise to
//  per-session.
//
//  UI-SPEC § Component Inventory § New views — single initializer
//  `init(intent: Intent)`. Renders the capitalized intent name as a
//  `.caption` accent-colored label inside a
//  `Capsule().fill(Color.accentColor.opacity(0.15))`.
//
//  Pure-value SwiftUI view — no `@State`, no `@Binding`, no model context
//  coupling. Per UI-SPEC § Stateful types this is NOT a stateful type
//  (informational, read-only); the chip is intentionally non-interactive in
//  v1 per 03.1-CONTEXT.md Claude's Discretion + Deferred Ideas (mid-session
//  intent change is out of scope).
//
//  Accessibility label format is `"Intent: \(intent.rawValue.capitalized)"`
//  — a load-bearing UI-SPEC Verification anchor; downstream copy tests
//  (Plan 08's SessionLoggerCopyTests refresh) anchor on this exact string.
//
//  Asset Contract: no new asset entries required. The chip uses
//  `AccentColor` (existing Phase 1 asset) + `Capsule()` shape + `.caption`
//  semantic font.
//
//  First consumer: `SessionLoggerView`'s principal toolbar block (Plan 06
//  Task 2 wires it as the third stacked line under the routine snapshot
//  name). Future consumers — Phase 6's session-comparison view, any other
//  surface that wants to surface a session's intent — reuse this component
//  rather than duplicating the layout.
//

import SwiftUI

public struct IntentChip: View {
    public let intent: Intent

    public init(intent: Intent) {
        self.intent = intent
    }

    public var body: some View {
        Text(intent.rawValue.capitalized)
            .font(.caption)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.accentColor.opacity(0.15))
            }
            .accessibilityLabel("Intent: \(intent.rawValue.capitalized)")
    }
}

#Preview("IntentChip variants") {
    VStack(spacing: 8) {
        IntentChip(intent: .strength)
        IntentChip(intent: .hypertrophy)
        IntentChip(intent: .power)
        IntentChip(intent: .endurance)
        IntentChip(intent: .technique)
    }
    .padding()
}
