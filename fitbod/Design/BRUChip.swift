// BRUChip.swift
// fitbod
//
// BRU chip primitive — a sharp-cornered rectangle label for category tags,
// intent chips, set-type labels, and filter controls in Phase 2 surfaces.
//
// Source of truth: UI-SPEC v2 § Component Inventory, line 510.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//
// USAGE:
//   BRUChip("Block")                                 // outline, bruInk
//   BRUChip("Intensification", color: .bruSignal, fill: true)  // filled signal
//   BRUChip("Compound", textCase: nil)               // outline, as-typed case

import SwiftUI

// MARK: - BRUChip

/// A brutalist outlined-rectangle chip for category tags, intent labels, and filters.
///
/// Renders a `Rectangle` outline (never `Capsule` or `RoundedRectangle`) with:
/// - `BRUFont.labelSmall` (10pt JetBrains Mono Bold)
/// - 1.2 letter spacing
/// - Optional `.uppercase` text transform (applied at view layer, not in source string)
/// - 6pt horizontal / 3pt vertical internal padding
///
/// Accessibility: the un-uppercased source string is always passed as the
/// `accessibilityLabel` so VoiceOver reads "strength" not "S-T-R-E-N-G-T-H".
public struct BRUChip: View {

    // MARK: - Properties

    private let label: String
    private let color: Color
    private let fill: Bool
    private let textCase: Text.Case?

    // MARK: - Init

    /// Creates a BRU chip.
    /// - Parameters:
    ///   - label: The chip's display string. Source string is stored as-typed for VoiceOver.
    ///   - color: Outline (and fill background) color. Defaults to `Color.bruInk`.
    ///   - fill: When `true`, renders `color` as the background fill with `Color.bruPaper` text.
    ///           When `false` (default), renders transparent background with `color` text + outline.
    ///   - textCase: Text transform applied at the view layer. Defaults to `.uppercase`.
    ///               Pass `nil` to render the label as-typed.
    // NOTE: Color? = nil pattern — generated Color.bru* tokens are `internal` and
    // cannot appear as default argument values in `public` inits under Swift 6.
    public init(
        _ label: String,
        color: Color? = nil,
        fill: Bool = false,
        textCase: Text.Case? = .uppercase
    ) {
        self.label = label
        self.color = color ?? .bruInk
        self.fill = fill
        self.textCase = textCase
    }

    // MARK: - Body

    public var body: some View {
        Text(label)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(textCase)
            .foregroundStyle(fill ? color.bruLabelOnFill : color.bruTextOnPaper)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill ? color : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(fill ? color : color.bruTextOnPaper, lineWidth: 1.5)
            )
            // VoiceOver must read the un-uppercased source string, not the visually
            // transformed uppercase version (UI-SPEC line 686 — T-02.1-02-03).
            .accessibilityLabel(label)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUChip") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Outline variants")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        HStack(spacing: 8) {
            BRUChip("Block")
            BRUChip("Strength", color: .bruSignal)
        }

        Text("Fill variants")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        HStack(spacing: 8) {
            BRUChip("Work", fill: true)
            BRUChip("Intensification", color: .bruSignal, fill: true)
        }

        Text("As-typed case")
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)

        HStack(spacing: 8) {
            BRUChip("Bench Press", textCase: nil)
            BRUChip("RPE autoreg", color: .bruSignal, textCase: nil)
        }
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
