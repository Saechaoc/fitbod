//
//  InlineRPEChipRow.swift
//  fitbod
//
//  Wave-4 plan 04-01 — the 5-chip RPE row inside `SetRow`. Per UI-SPEC
//  § Session logger:
//
//    "RPE inline-chip row labels: 6 / 7 / 8 / 9 / 10 (5 visible chips;
//     decimal RPE via long-press → wheel picker tenths)"
//
//  Tap an integer chip → sets `entry.rpe = Double(value)`.
//  Long-press any chip (0.5s threshold per UI-SPEC accessibility) →
//  presents `DecimalRPEPickerSheet` with the long-pressed integer pre-
//  selected. The user spins the wheel to a decimal value (6.0…10.0 in 0.5
//  increments) and "Done" dismisses.
//
//  Each chip is 36pt visual but the parent's `SetRow` row padding extends
//  the hit area to ≥44pt (UI-SPEC HIG exception). Each chip carries an
//  `accessibilityLabel = "RPE {N}"` (UI-SPEC accessibility § RPE chip row).
//
//  The currently-selected chip is tinted `Color.accentColor` (chips are an
//  accent surface per UI-SPEC § Color "Selected intent filter chip" — the
//  same chip selection pattern applies). Unselected chips render in
//  `.secondary` tint per the system `.bordered` button style.
//

import SwiftUI

public struct InlineRPEChipRow: View {
    @Binding public var rpe: Double?
    @State private var presentingPicker = false
    /// The integer the user long-pressed, used as the picker's initial value
    /// when `rpe` is nil. Captured at long-press time so the wheel doesn't
    /// snap to 6.0 when the user long-presses "9".
    @State private var longPressedValue: Double = 8

    public init(rpe: Binding<Double?>) {
        self._rpe = rpe
    }

    public var body: some View {
        HStack(spacing: 4) {                                                  // UI-SPEC xs
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button("\(value)") {
                    rpe = Double(value)
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(Int(rpe ?? 0) == value ? Color.accentColor : Color.secondary)
                .frame(minWidth: 36, minHeight: 36)
                .onLongPressGesture(minimumDuration: 0.5) {
                    longPressedValue = Double(value)
                    presentingPicker = true
                }
                .accessibilityLabel("RPE \(value)")
            }
        }
        .sheet(isPresented: $presentingPicker) {
            DecimalRPEPickerSheet(rpe: Binding(
                get: { rpe ?? longPressedValue },
                set: { rpe = $0 }
            ))
            .presentationDetents([.fraction(0.3)])
        }
    }
}

#Preview("RPE chip row") {
    @Previewable @State var rpe: Double? = 8
    return InlineRPEChipRow(rpe: $rpe).padding()
}
