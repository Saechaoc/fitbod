// BRUDivider.swift
// fitbod
//
// BRU horizontal rule primitive — replaces every SwiftUI Divider() call
// in Phase 2 surfaces. Two weights: hair (1pt bruHair) and ink (2pt bruInk).
//
// Source of truth: UI-SPEC v2 § Component Inventory, line 82.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor
//
// USAGE:
//   BRUDivider()          // .hair — 1pt bruHair (list-row separator)
//   BRUDivider(.ink)      // .ink  — 2pt bruInk  (section boundary rule)

import SwiftUI

// MARK: - BRUDivider

/// A horizontal rule in the BRU visual language.
///
/// Two weights are supported:
/// - `.hair` — 1pt, rendered in `Color.bruHair`. Used between consecutive list rows.
/// - `.ink` — 2pt, rendered in `Color.bruInk`. Used for section-level boundaries.
///
/// Replaces all SwiftUI `Divider()` calls in Phase 2+ surfaces.
/// Never renders at sub-pixel hairline; always an explicit `Rectangle` with a fixed height.
public struct BRUDivider: View {

    // MARK: - Kind

    /// The visual weight of the dividing rule.
    public enum Kind {
        /// 1pt, rendered in `Color.bruHair` — quiet list-row separator.
        case hair
        /// 2pt, rendered in `Color.bruInk` — prominent section boundary.
        case ink

        var height: CGFloat {
            switch self {
            case .hair: return 1
            case .ink: return 2
            }
        }

        var color: Color {
            switch self {
            case .hair: return .bruHair
            case .ink: return .bruInk
            }
        }
    }

    // MARK: - Properties

    private let kind: Kind

    // MARK: - Init

    /// Creates a BRU horizontal rule.
    /// - Parameter kind: Visual weight — `.hair` (1pt, default) or `.ink` (2pt).
    public init(_ kind: Kind = .hair) {
        self.kind = kind
    }

    // MARK: - Body

    public var body: some View {
        Rectangle()
            .fill(kind.color)
            .frame(height: kind.height)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUDivider") {
    VStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hair (1pt bruHair)")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            BRUDivider(.hair)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Ink (2pt bruInk)")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            BRUDivider(.ink)
        }
    }
    .padding(16)
    .background(Color.bruPaper)
}
#endif
