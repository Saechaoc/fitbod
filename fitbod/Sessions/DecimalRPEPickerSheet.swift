// DecimalRPEPickerSheet.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 35).
// UI-SPEC v2 § Session logger line 376: "Decimal RPE sheet title: 'RPE' (header band)".
// Uses BRUHeaderBar('RPE') with CANCEL left and DONE right (signal).
//
// The wheel Picker chrome is system-default per UI-SPEC line 261:
// "Apple's wheel picker chrome cannot be restyled — system chrome acceptable."
// Footer hint text uses BRUFont.bodyDefault / bruMuted.
//
// The wheel keeps its own value: Done hands it to `onDone`, and Cancel (or a
// swipe down) drops it.
//
// BRU contract: NO navigationTitle / NO .toolbar with system chrome
//               NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .buttonStyle(.bordered)
//               NO Color(.system*) / NO .font(.body/.headline/.title)

import SwiftUI

public struct DecimalRPEPickerSheet: View {
    @State private var selection: Double
    private let onDone: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    /// 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0 per UI-SPEC.
    private let options: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    public init(initial: Double, onDone: @escaping (Double) -> Void) {
        // Start on a wheel value, even for an old typed target such as 7.8.
        self._selection = State(initialValue: min(max((initial * 2).rounded() / 2, 6), 10))
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 0) {
            // BRUHeaderBar replaces NavigationStack + .navigationTitle chrome.
            BRUHeaderBar(
                left: HeaderAction("Cancel") { dismiss() },
                center: "RPE",
                right: HeaderAction("Done", isSignal: true) {
                    onDone(selection)
                    dismiss()
                }
            )

            // Wheel picker — system chrome is acceptable per UI-SPEC line 261.
            Picker("RPE", selection: $selection) {
                ForEach(options, id: \.self) { v in
                    Text(String(format: "%.1f", v)).tag(v)
                }
            }
            .pickerStyle(.wheel)

            // Footer hint
            Text("Long-press any chip for decimal precision")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Decimal RPE picker sheet") {
    @Previewable @State var rpe: Double = 8.0
    return Text("RPE: \(rpe, specifier: "%.1f")")
        .font(BRUFont.bodyEmphasis)
        .sheet(isPresented: .constant(true)) {
            DecimalRPEPickerSheet(initial: rpe) { rpe = $0 }
                .presentationDetents([.fraction(0.3)])
        }
}
#endif
