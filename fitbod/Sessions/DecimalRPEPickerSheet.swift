//
//  DecimalRPEPickerSheet.swift
//  fitbod
//
//  Wave-4 plan 04-01 — wheel picker presented from a long-press on any
//  `InlineRPEChipRow` chip. Surfaces a wheel `Picker` over RPE values from
//  6.0 through 10.0 in 0.5 increments (UI-SPEC § Session logger "Decimal
//  RPE long-press picker — Picker wheel showing 1.0 increments of 0.5").
//
//  The sheet is presented at `.fraction(0.3)` detent (small, focused) per
//  the plan body to keep the rest of the session logger visible while the
//  user dials in a decimal RPE. The "Done" toolbar action dismisses the
//  sheet; selection is committed live as the wheel scrolls (SwiftUI
//  `Picker` binding semantics).
//
//  The picker title "RPE" is UI-SPEC verbatim (§ Session logger "Decimal
//  RPE long-press sheet title").
//

import SwiftUI

public struct DecimalRPEPickerSheet: View {
    @Binding public var rpe: Double
    @Environment(\.dismiss) private var dismiss

    /// 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0 (per UI-SPEC).
    private let options: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    public init(rpe: Binding<Double>) {
        self._rpe = rpe
    }

    public var body: some View {
        NavigationStack {
            Picker("RPE", selection: $rpe) {
                ForEach(options, id: \.self) { v in
                    Text(String(format: "%.1f", v)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle("RPE")                                            // UI-SPEC verbatim
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("decimal picker") {
    @Previewable @State var rpe: Double = 8.0
    return Text("RPE: \(rpe, specifier: "%.1f")")
        .sheet(isPresented: .constant(true)) {
            DecimalRPEPickerSheet(rpe: $rpe)
                .presentationDetents([.fraction(0.3)])
        }
}
