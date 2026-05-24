// IntentChip.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 07 (Wave 3, UI-REVIEW item 48).
// UI-SPEC v2 § Color line 209 / 268-269: renders a single BRUChip per intent.
//
// Per UI-SPEC line 17 (ExerciseHistoryView intent chip note):
//   "strength intent chip: signal outline; hypertrophy/other: ink outline."
// SessionLoggerView line 363: signal-FILL only when intent is "Strength".
//
// Accessibility: preserves "Intent: \(intent.rawValue.capitalized)" verbatim
// per UI-SPEC Verification anchor (line 686). The .textCase(.uppercase) in
// BRUChip renders visually uppercase but VoiceOver reads the underlying string.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//               NO Image(systemName:) / NO .font(.caption) / NO Color(.system*)

import SwiftUI

public struct IntentChip: View {
    public let intent: Intent

    public init(intent: Intent) {
        self.intent = intent
    }

    public var body: some View {
        BRUChip(
            intent.rawValue.capitalized,
            color: intent == .strength ? .bruSignal : .bruInk,
            fill: intent == .strength
        )
        // Accessibility: reads un-uppercased format for VoiceOver per UI-SPEC line 686.
        .accessibilityLabel("Intent: \(intent.rawValue.capitalized)")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("IntentChip variants") {
    VStack(alignment: .leading, spacing: 8) {
        IntentChip(intent: .strength)    // signal fill
        IntentChip(intent: .hypertrophy) // ink outline
        IntentChip(intent: .power)       // ink outline
        IntentChip(intent: .endurance)   // ink outline
        IntentChip(intent: .technique)   // ink outline
    }
    .padding()
    .background(Color.bruPaper)
}
#endif
