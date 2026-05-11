//
//  PlaceholderTabView.swift
//  fitbod
//
//  Single-line placeholder body for the three Phase 1 tabs that have no
//  real content yet — Today, Routines, Progress. Each gets its own
//  `NavigationStack` (per UI-SPEC.md tab-labels table + RESEARCH § State
//  of the Art "TabView NOT wrapped in parent NavigationStack").
//
//  Copy locked by UI-SPEC.md § Tab labels — "Available in Phase {N}"
//  with no marketing voice and no hand-holding. The phase number
//  (`2` for Today / Routines, `6` for Progress) is the only variable.
//
//  Replaced in later phases:
//    - Today    → Phase 2 (`SessionView`)
//    - Routines → Phase 2 (`RoutineListView`)
//    - Progress → Phase 6 (`ProgressView`)
//

import SwiftUI

/// Single-line placeholder for tabs not implemented in Phase 1.
/// Copy locked by UI-SPEC.md § Tab labels.
public struct PlaceholderTabView: View {
    let phaseNumber: Int

    public init(phaseNumber: Int) {
        self.phaseNumber = phaseNumber
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Available in Phase \(phaseNumber)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview { PlaceholderTabView(phaseNumber: 2) }
