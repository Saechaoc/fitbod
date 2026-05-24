// PinnedNoteCapsule.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 46).
// UI-SPEC v2 § Color line 221 + Component line 332 + 368.
//
// The inline pinned-note indicator that displays a SessionExercise.pinnedNote
// value above the column-header row in SessionExerciseCard. Tapping opens
// PinnedNoteSheet for editing.
//
// CRITICAL: UI-SPEC line 221 EXPLICITLY BANS the system yellow color token.
// This rewrite removes ALL references to the yellow token, the pin glyph, and Capsule.
//
// UI-SPEC visual contract:
//   Background:  Color.bruBg2 fill + 1.5pt bruInk stroke Rectangle (UI-SPEC line 332 / 368)
//   Glyph:       InkSquareGlyph — 8pt ink square + 2pt offset notch via Canvas + Path (UI-SPEC line 368)
//   Text:        BRUFont.bodyDefault bruInk
//   Shape:       Rectangle (NOT Capsule — UI-SPEC line 349)
//
// BRU contract:
//   NO system yellow color token — explicitly banned per UI-SPEC line 221
//   NO pin SF symbol — replaced by InkSquareGlyph
//   NO capsule clip shape — replaced by Rectangle stroke overlay
//   NO RoundedRectangle / NO accentColor / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI

// MARK: - InkSquareGlyph

/// Fileprivate pin marker: an 8pt ink square with a 2pt offset notch rendered
/// via Canvas + Path. Approximates the ink-square-with-notch mockup per
/// UI-SPEC line 368. The notch offset clips 2pt outside the canvas frame —
/// this is the intended approximation (T-02.1-08-05: accepted).
fileprivate struct InkSquareGlyph: View {
    var body: some View {
        Canvas { ctx, _ in
            // Main 8×8 ink square
            ctx.fill(
                Path(CGRect(x: 0, y: 2, width: 8, height: 8)),
                with: .color(Color.bruInk)
            )
            // 2pt offset notch on top-right — approximates the pin-head notch
            ctx.fill(
                Path(CGRect(x: 6, y: 0, width: 4, height: 4)),
                with: .color(Color.bruInk)
            )
        }
        .frame(width: 12, height: 10)
    }
}

// MARK: - PinnedNoteCapsule

public struct PinnedNoteCapsule: View {
    public let note: String
    public let onTap: () -> Void

    public init(note: String, onTap: @escaping () -> Void) {
        self.note = note
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                // Ink-square glyph replaces the pin SF symbol per UI-SPEC line 368
                InkSquareGlyph()

                Text(note)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruInk)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.bruBg2)                                             // UI-SPEC line 332
            .overlay(
                Rectangle()
                    .stroke(Color.bruInk, lineWidth: 1.5)                         // UI-SPEC line 332 / 368
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pinned note: \(note)")                                // UI-SPEC verbatim a11y
        .accessibilityHint("Tap to edit")
    }
}

#if DEBUG
#Preview("pinned note capsule") {
    VStack(spacing: 16) {
        PinnedNoteCapsule(note: "Keep elbows tucked") {}
        PinnedNoteCapsule(note: "Right knee caved on rep 7 — reduce weight next session") {}
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
