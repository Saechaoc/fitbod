//
//  SeriesToggleChipRow.swift
//  fitbod
//
//  Wave-3 plan 06-05 — horizontal pair of `ProgressFilterChip`s above
//  the `ExerciseProgressView` chart. CONTEXT D-07 + UI-SPEC
//  § ExerciseProgressView § "Series toggle chips".
//
//  Both chips default ON when the parent view's @State is initialized;
//  this view does not own state — the parent passes @Bindings so the
//  user's selection survives navigation back-and-forth within the
//  same NavigationStack.
//
//  Verbatim copy (UI-SPEC item 614):
//    chip 1 label: "Top set"           accessibility: "Top set series"
//    chip 2 label: "All-set avg"       accessibility: "All-set average series"
//

import SwiftUI

public struct SeriesToggleChipRow: View {
    @Binding public var showTopSet: Bool
    @Binding public var showAllAvg: Bool

    public init(showTopSet: Binding<Bool>, showAllAvg: Binding<Bool>) {
        self._showTopSet = showTopSet
        self._showAllAvg = showAllAvg
    }

    public var body: some View {
        HStack(spacing: 8) {
            ProgressFilterChip(
                label: "Top set",
                accessibilityName: "Top set series",
                isActive: showTopSet
            ) {
                showTopSet.toggle()
            }
            ProgressFilterChip(
                label: "All-set avg",
                accessibilityName: "All-set average series",
                isActive: showAllAvg
            ) {
                showAllAvg.toggle()
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
