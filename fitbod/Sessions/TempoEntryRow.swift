// TempoEntryRow.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 39).
// UI-SPEC v2 § Session logger line 382.
//
// Opt-in 4-field tempo entry row (SESS-07). Renders only when the parent
// SessionExerciseCard decides sessionExercise.tracksTempo == true.
//
// UI-SPEC verbatim:
//   Leading section label: "TEMPO"     (labelSmall 10pt, 1.2 letterspacing)
//   Field labels:          "ECC" / "BOT" / "CON" / "TOP"  (labelSmall above each field)
//   Fields:                BRUFont.bodyDefault mono 12pt, outlined Rectangle 1pt bruInk
//
// Persistence semantics:
//   Empty → tempoActual = nil (no "0-0-0-0" ghosts in history).
//   Non-empty → joined with "-" (e.g. "3-1-1-0"). Round-trip symmetric.
//
// BRU contract:
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct TempoEntryRow: View {
    @Bindable public var entry: SetEntry
    @State private var components: [String] = ["", "", "", ""]
    @FocusState private var focusedField: Int?

    private let fieldLabels = ["ECC", "BOT", "CON", "TOP"]                        // UI-SPEC verbatim labels

    public init(entry: SetEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Leading section label per UI-SPEC line 382
            Text("TEMPO")                                                           // UI-SPEC verbatim
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            HStack(spacing: 8) {
                ForEach(Array(fieldLabels.enumerated()), id: \.offset) { idx, label in
                    VStack(spacing: 4) {
                        // Sub-label above each field (labelSmall 10pt, 1.2 letterspacing)
                        Text(label)
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)

                        // Mono TextField with 1pt bruInk outlined Rectangle
                        TextField("—", text: Binding(
                            get: { components[idx] },
                            set: { newValue in
                                components[idx] = newValue
                                persistTempo()
                            }
                        ))
                        .font(BRUFont.bodyDefault)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: idx)
                        // A digit typed into the field replaces the one it
                        // shows (T39).
                        .selectsAllOnFocus(focusedField == idx)
                        .frame(minWidth: 40, minHeight: 32)
                        .overlay(
                            Rectangle()
                                .stroke(Color.bruInk, lineWidth: 1)
                        )
                        .accessibilityIdentifier("set.tempo.\(label.lowercased()).\(identifierSuffix)")
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
        // The focused row scrolls clear of the keyboard and its DONE (T39).
        .revealsAboveKeyboard(focusedField != nil)
        .onAppear {
            // Re-hydrate the four fields from the persisted tempoActual
            let parts = (entry.tempoActual ?? "").split(
                separator: "-",
                omittingEmptySubsequences: false
            ).map(String.init)
            for i in 0..<4 {
                components[i] = i < parts.count ? parts[i] : ""
            }
        }
    }

    /// Persists the dash-joined tempo to SetEntry.tempoActual.
    /// Empty across the board → nil so history doesn't accumulate ghost rows.
    private func persistTempo() {
        let allEmpty = components.allSatisfy { $0.isEmpty }
        entry.tempoActual = allEmpty ? nil : components.joined(separator: "-")
    }

    /// The set's identifier suffix, such as "1.S1", as SetRow gives it.
    private var identifierSuffix: String {
        SetRow.identifierSuffix(for: entry, in: entry.sessionExercise)
    }
}

#if DEBUG
#Preview("tempo entry row") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    se.tracksTempo = true
    ctx.insert(se)
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.tempoActual = "3-1-1-0"
    ctx.insert(entry)
    try? ctx.save()
    return TempoEntryRow(entry: entry)
        .modelContainer(container)
        .padding()
        .background(Color.bruPaper)
}
#endif
