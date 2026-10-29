// InlineRPEChipRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 34).
// UI-SPEC v2 § Session logger line 374-376: 5 BRUChip-style outlined rectangles.
// Each chip: displayMedium 18pt centered numeric; selected = bruInk fill +
// bruPaper text; unselected = bruPaper fill + bruInk text + bruInk 1.5pt outline.
//
// Tap an integer chip → sets `rpe = Double(value)`.
// Long-press any chip (0.5s threshold per UI-SPEC accessibility) →
// presents DecimalRPEPickerSheet with the long-pressed integer pre-selected.
// With a `noneLabel`, a trailing chip clears `rpe`, so "no RPE" is an
// explicit choice (the prescription editor's no-target option). The logger
// passes none and keeps the five chips.
//
// BRU contract: NO capsule shapes / NO RoundedRectangle / NO accent color
//               NO Image(systemName:) / NO bordered button style
//               NO Color(.system*) / NO .font(.caption/.body/.headline)

import SwiftUI

public struct InlineRPEChipRow: View {
    @Binding public var rpe: Double?
    private let noneLabel: String?
    @State private var presentingPicker = false
    /// The integer the user long-pressed, used as the picker's initial value
    /// when `rpe` is nil. Captured at long-press time so the wheel doesn't
    /// snap to 6.0 when the user long-presses "9".
    @State private var longPressedValue: Double = 8

    public init(rpe: Binding<Double?>, noneLabel: String? = nil) {
        self._rpe = rpe
        self.noneLabel = noneLabel
    }

    public var body: some View {
        BRUFlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                let selected = Int(rpe ?? -1) == value
                Button {
                    rpe = Double(value)
                } label: {
                    // UI-SPEC line 374: displayMedium 18pt centered in chip.
                    // Selected: bruInk fill + bruPaper text.
                    // Unselected: bruPaper fill + bruInk text + 1.5pt bruInk outline.
                    Text("\(value)")
                        .font(BRUFont.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(selected ? Color.bruPaper : Color.bruInk)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(selected ? Color.bruInk : Color.bruPaper)
                        .overlay(
                            Rectangle()
                                .stroke(Color.bruInk, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .onLongPressGesture(minimumDuration: 0.5) {
                    longPressedValue = Double(value)
                    presentingPicker = true
                }
                .accessibilityLabel("RPE \(value)")                            // UI-SPEC verbatim a11y
            }
            if let noneLabel {
                let selected = rpe == nil
                Button {
                    rpe = nil
                } label: {
                    Text(noneLabel)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(selected ? Color.bruPaper : Color.bruInk)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(selected ? Color.bruInk : Color.bruPaper)
                        .overlay(
                            Rectangle()
                                .stroke(Color.bruInk, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(noneLabel)
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

// MARK: - Previews

#if DEBUG
#Preview("RPE chip row — value selected") {
    @Previewable @State var rpe: Double? = 8
    return InlineRPEChipRow(rpe: $rpe)
        .padding()
        .background(Color.bruPaper)
}

#Preview("RPE chip row — no selection") {
    @Previewable @State var rpe: Double? = nil
    return InlineRPEChipRow(rpe: $rpe)
        .padding()
        .background(Color.bruPaper)
}

#Preview("RPE chip row — decimal value (7.5)") {
    @Previewable @State var rpe: Double? = 7.5
    return InlineRPEChipRow(rpe: $rpe)
        .padding()
        .background(Color.bruPaper)
}

#Preview("RPE chip row — no-target chip selected") {
    @Previewable @State var rpe: Double? = nil
    return InlineRPEChipRow(rpe: $rpe, noneLabel: "No target")
        .padding()
        .background(Color.bruPaper)
}
#endif
