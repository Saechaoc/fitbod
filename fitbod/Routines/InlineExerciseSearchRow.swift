//
//  InlineExerciseSearchRow.swift
//  fitbod
//
//  Phase 2.1 Plan 05 REWRITE — replaces the SF symbol plus.circle +
//  accentColor button with a BRUDashedSlot trigger.
//
//  The selected `Exercise` is forwarded to the parent via the `onSelect` closure,
//  which the routine builder uses to append a new `RoutineExerciseDraft`.
//
//  Verbatim copy: "Add exercise" + "↘ FROM LIBRARY" — anchored in
//  RoutineBuilderBRUCopyTests + RoutineBuilderCopyTests.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule / NO RoundedRectangle
//

import SwiftUI

public struct InlineExerciseSearchRow: View {
    @State private var presentingPicker: Bool = false
    public let onSelect: (Exercise) -> Void

    public init(onSelect: @escaping (Exercise) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        BRUDashedSlot(
            label: "Add exercise",
            hint: "↘ FROM LIBRARY",
            leadingGlyph: "+",
            action: { presentingPicker = true }
        )
        .accessibilityLabel("Add exercise")
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

// MARK: - Preview

#if DEBUG
#Preview("InlineExerciseSearchRow") {
    InlineExerciseSearchRow { _ in }
        .padding(12)
        .background(Color.bruPaper)
}
#endif
