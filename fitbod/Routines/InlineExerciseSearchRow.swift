//
//  InlineExerciseSearchRow.swift
//  fitbod
//
//  Wave-3 plan 03-02 — the sticky bottom-of-list "Add an exercise"
//  affordance in the routine builder. Renders as a `Button` row that
//  opens `ExerciseLibraryView(onSelect:)` in a `.sheet` wrapped in a
//  `NavigationStack`. The selected `Exercise` is forwarded to the
//  parent via the `onSelect` closure, which the routine builder uses
//  to append a new `RoutineExerciseDraft` to its `RoutineDraft`.
//
//  ## UI-SPEC trade-off (documented)
//
//  UI-SPEC § Routine builder § Interaction patterns describes the
//  inline search as truly inline (`.searchable(text:)` on the same
//  `ScrollView`, results surfaced as a `LazyVStack` *inside* the
//  same scroll view). Phase 2 implements this as a sheet-presented
//  picker instead — the picker still reuses Phase 1's
//  `ExerciseLibraryView` in picker mode (`onSelect:` closure, RESEARCH
//  § Pattern 5), but the picker comes up in a sheet rather than
//  rendering inline.
//
//  Rationale:
//    1. Reusing `ExerciseLibraryView` in picker mode delivers the same
//       filter facets / search debounce / empty-state behavior that
//       the standalone library tab ships — the user experience is
//       consistent across the two surfaces.
//    2. Embedding the full library list inline would require an
//       in-Form `ScrollView` + `@Query<Exercise>` parallel to the
//       routine draft's exercise list — a clearer plan 04-01 polish
//       than a Phase 2 v1 must-have.
//
//  The trade-off is documented here AND in the plan 03-02 SUMMARY.
//

import SwiftUI

public struct InlineExerciseSearchRow: View {
    @State private var presentingPicker: Bool = false
    public let onSelect: (Exercise) -> Void

    public init(onSelect: @escaping (Exercise) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        Button {
            presentingPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.accentColor)
                Text("Add an exercise")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an exercise")
        .sheet(isPresented: $presentingPicker) {
            NavigationStack {
                ExerciseLibraryView(onSelect: { exercise in
                    onSelect(exercise)
                    presentingPicker = false
                })
            }
        }
    }
}
