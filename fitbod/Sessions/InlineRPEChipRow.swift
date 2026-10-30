// InlineRPEChipRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 34).
// UI-SPEC v2 § Session logger line 374-376: 5 BRUChip-style outlined rectangles.
// Each chip: displayMedium 18pt centered numeric; selected = bruInk fill +
// bruPaper text; unselected = bruPaper fill + bruInk text + bruInk 1.5pt outline.
//
// Tap a chip → sets `rpe` to its value.
// Long-press any chip (0.5s threshold per UI-SPEC accessibility) →
// presents DecimalRPEPickerSheet with the long-pressed value pre-selected.
// Done writes the picked value; Cancel leaves `rpe` as it was.
// A stored value between the whole numbers, such as 8.5, gets its own
// selected chip, so it never shows or reads to VoiceOver as chip 8.
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
    /// The chip the user long-pressed; the picker starts there.
    @State private var longPressedValue: Double = 8

    public init(rpe: Binding<Double?>, noneLabel: String? = nil) {
        self._rpe = rpe
        self.noneLabel = noneLabel
    }

    /// The five whole numbers, plus the stored value when it is not one of
    /// them, such as 8.5.
    private var chipValues: [Double] {
        let whole: [Double] = [6, 7, 8, 9, 10]
        guard let rpe, !whole.contains(rpe) else { return whole }
        return (whole + [rpe]).sorted()
    }

    public var body: some View {
        BRUFlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(chipValues, id: \.self) { value in
                let selected = rpe == value
                Button {
                    // A hold also ends in this tap; the picker it opened
                    // decides the value instead.
                    guard !presentingPicker else { return }
                    rpe = value
                } label: {
                    // UI-SPEC line 374: displayMedium 18pt centered in chip.
                    // Selected: bruInk fill + bruPaper text.
                    // Unselected: bruPaper fill + bruInk text + 1.5pt bruInk outline.
                    Text(Self.label(for: value))
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
                // A Button swallows .onLongPressGesture, so the hold is
                // watched alongside the button's own tap.
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    longPressedValue = value
                    presentingPicker = true
                })
                .accessibilityLabel("RPE \(Self.label(for: value))")          // UI-SPEC verbatim a11y
                .accessibilityAddTraits(selected ? .isSelected : [])
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
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sheet(isPresented: $presentingPicker) {
            DecimalRPEPickerSheet(initial: longPressedValue) { rpe = $0 }
                .presentationDetents([.fraction(0.3)])
        }
    }

    /// "8" for a whole number, "8.5" otherwise.
    private static func label(for value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
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
