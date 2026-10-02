// BRUDisplay.swift
// fitbod
//
// BRU display text primitive — Space Grotesk Bold in three hero sizes.
// Used for session titles, stat-strip values, and CTA headlines.
//
// Source of truth: UI-SPEC v2 § Component Inventory, line ~512 + Typography § displayHero/Large/Medium.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//
// USAGE:
//   BRUDisplay("Push A",     size: .hero,   color: .bruPaper)  // 56pt on ink slab
//   BRUDisplay("Upper",      size: .large)                     // 32pt section heading
//   BRUDisplay("14",         size: .medium, color: .bruInk)    // 18pt stat value

import SwiftUI

// MARK: - BRUDisplaySize

/// The three display-text size tiers in the BRU type scale.
public enum BRUDisplaySize {
    /// 56pt — hero headlines, CTA slabs, e1RM hero numbers.
    case hero
    /// 32pt — section headers, routine names in the builder.
    case large
    /// 18pt — stat strip values, set indices, section dates.
    case medium

    /// Point size for `Font.custom(_:size:)`.
    public var pointSize: CGFloat {
        switch self {
        case .hero:   return 56
        case .large:  return 32
        case .medium: return 18
        }
    }

    /// Tracking (letter spacing) applied at the call site.
    public var tracking: CGFloat {
        switch self {
        case .hero:   return -0.5
        case .large:  return -0.3
        case .medium: return 0
        }
    }
}

// MARK: - BRUDisplay

/// A display-weight text view using Space Grotesk Bold at one of three BRU sizes.
///
/// Line spacing is collapsed (`.lineSpacing(0)`) so consecutive display lines
/// sit at the `lineHeight: 1` rhythm specified in UI-SPEC v2.
///
/// Use `BRUFont.displayHero` / `displayLarge` / `displayMedium` for inline text
/// where you need mixed tracking on a `Text` modifier chain. Use `BRUDisplay`
/// when the text is a standalone display element with a color binding.
///
/// The nested `Size` typealias is provided so Phase 04.1 surfaces and `BRUReadout`
/// can reference `BRUDisplay.Size` instead of the top-level `BRUDisplaySize`.
public struct BRUDisplay: View {

    /// Nested type alias for `BRUDisplaySize` — allows call sites to reference
    /// `BRUDisplay.Size` per the 04.1 interface contract while keeping the top-level
    /// `BRUDisplaySize` for backward compatibility with existing callers.
    public typealias Size = BRUDisplaySize

    // MARK: - Properties

    private let text: String
    private let size: BRUDisplaySize
    private let color: Color

    // MARK: - Init

    /// Creates a BRU display text element.
    /// - Parameters:
    ///   - text: The display string. Case is as-typed (apply `.textCase` at call site if needed).
    ///   - size: Display tier — `.hero` (56pt), `.large` (32pt), or `.medium` (18pt).
    ///   - color: Foreground color. Defaults to `Color.bruInk`.
    // NOTE: Color? = nil pattern — generated Color.bru* tokens are `internal` and
    // cannot appear as default argument values in `public` inits under Swift 6.
    // NOTE: size defaults to .large per the 04.1 interface contract; existing callers
    // that pass size: explicitly continue to work unchanged.
    public init(_ text: String, size: BRUDisplaySize = .large, color: Color? = nil) {
        self.text = text
        self.size = size
        self.color = color ?? .bruInk
    }

    // MARK: - Body

    public var body: some View {
        Text(text)
            .font(.bru(.grotesk, size: size.pointSize))
            .tracking(size.tracking)
            .foregroundStyle(color)
            .lineSpacing(0)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUDisplay") {
    VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hero — 56pt")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            BRUDisplay("Push A", size: .hero)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Large — 32pt")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            BRUDisplay("Upper Hypertrophy", size: .large)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Medium — 18pt")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            HStack(spacing: 16) {
                BRUDisplay("14", size: .medium)
                BRUDisplay("42", size: .medium)
                BRUDisplay("↑", size: .medium, color: .bruSignal)
            }
        }

        // Ink-slab usage — paper text on ink background
        VStack(alignment: .leading, spacing: 4) {
            Text("On ink slab")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            BRUDisplay("Push A", size: .hero, color: .bruPaper)
                .padding(16)
                .background(Color.bruInk)
        }
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
