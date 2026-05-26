// BRUPillButton.swift
// fitbod — Phase 2.1 Plan 03
//
// The primary CTA button: signal-fill rectangle with paper text.
// Despite the "Pill" name, this is a RECTANGLE — no rounded corners.
// UI-SPEC v2 line 522: "Pill" name is a misnomer; it's a rectangle.
//
// Reference: bru-screens/today.jsx line 77 ("Start workout ▸")
//
// USAGE:
//   BRUPillButton("Start workout ▸") { startWorkout() }
//   BRUPillButton("Save routine ▸") { saveRoutine() }

import SwiftUI

// MARK: - BRUPillButton

/// Signal-fill rectangle CTA button.
///
/// Layout:
/// ```
/// ┌──────────────────────────────────────┐  ← bruSignal fill
/// │         START WORKOUT ▸              │  16pt vertical padding
/// └──────────────────────────────────────┘
/// ```
///
/// NO rounded corners (the "Pill" name is a misnomer per UI-SPEC v2 line 522).
/// Full-width by default via `frame(maxWidth: .infinity)`.
/// Text: `BRUFont.labelSmall` 11pt UPPERCASE 1.2 letterspacing `bruPaper`.
public struct BRUPillButton: View {

    // MARK: Properties

    private let label: String
    private let fill: Color
    private let action: @MainActor () -> Void

    // MARK: Init

    /// Creates a BRUPillButton.
    /// - Parameters:
    ///   - label: Button label text. Rendered uppercase via `.textCase(.uppercase)`.
    ///   - fill: Background fill color. Defaults to `Color.bruSignal` per BRU CTA contract.
    ///           Use `Color.bruInk` for primary dark fill per the 04.1 interface contract.
    ///           NOTE: `Color? = nil` pattern — generated Color.bru* tokens are `internal` under
    ///           Swift 6 MemberImportVisibility and cannot be default argument values in public inits.
    ///   - action: Closure invoked on tap.
    public init(_ label: String, fill: Color? = nil, action: @escaping @MainActor () -> Void) {
        self.label = label
        self.fill = fill ?? .bruSignal
        self.action = action
    }

    // MARK: Body

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruPaper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(fill)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Start workout ▸") {
    VStack(spacing: 16) {
        BRUPillButton("Start workout ▸") {}

        BRUPillButton("Save routine ▸") {}

        BRUPillButton("Resume ▸") {}
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
