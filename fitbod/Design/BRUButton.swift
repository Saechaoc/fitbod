// BRUButton.swift
// fitbod
//
// BRU button primitive — a sharp-cornered brutalist button in three kind variants
// (primary, signal, ghost) and three size variants (sm, md, lg).
//
// Source of truth: UI-SPEC v2 § Component Inventory, line 514.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//               NO .buttonStyle(.bordered) — ALWAYS .buttonStyle(.plain)
//
// USAGE:
//   BRUButton("Save routine ▸", kind: .signal, size: .lg) { save() }
//   BRUButton("Discard",        kind: .ghost)              { discard() }
//   BRUButton("Confirm")                                   { confirm() }

import SwiftUI

// MARK: - BRUButton

/// A brutalist full-width button with no rounded corners and no Apple HIG chrome.
///
/// Three `Kind` variants control the fill + text + border treatment:
/// - `.primary` — ink fill, paper text (solid ink slab)
/// - `.signal`  — signal fill, paper text (strong CTA)
/// - `.ghost`   — transparent fill, ink text, 1.5pt ink outline
///
/// Three `Size` variants set the minimum tap-target height (all ≥ 32pt,
/// meeting BRU's 44pt touch-target mandate for `.md` and `.lg`).
///
/// `.buttonStyle(.plain)` is mandatory — it suppresses Apple's default bordered
/// and borderless chrome tinting that would violate the BRU contract (T-02.1-02-02).
public struct BRUButton: View {

    // MARK: - Kind

    /// The visual treatment variant of the button.
    public enum Kind {
        /// Ink fill with paper text — default strong action.
        case primary
        /// Signal fill with paper text — the single primary CTA per screen.
        case signal
        /// Transparent fill with ink text and a 1.5pt ink outline — secondary / destructive-neutral.
        case ghost

        fileprivate var fillColor: Color {
            switch self {
            case .primary: return .bruInk
            case .signal:  return .bruSignal
            case .ghost:   return .clear
            }
        }

        fileprivate var textColor: Color {
            switch self {
            case .primary, .signal: return .bruPaper
            case .ghost:            return .bruInk
            }
        }

        fileprivate var borderColor: Color {
            switch self {
            case .primary: return .bruInk
            case .signal:  return .bruSignal
            case .ghost:   return .bruInk
            }
        }

        fileprivate var showBorder: Bool {
            switch self {
            case .primary, .signal: return false
            case .ghost:            return true
            }
        }
    }

    // MARK: - Size

    /// The vertical size tier of the button.
    public enum Size {
        /// 32pt minimum height — compact inline actions.
        case sm
        /// 44pt minimum height — standard tappable controls (iOS HIG touch target).
        case md
        /// 52pt minimum height — prominent full-width CTAs.
        case lg

        /// Minimum height for the button's frame.
        public var minHeight: CGFloat {
            switch self {
            case .sm: return 32
            case .md: return 44
            case .lg: return 52
            }
        }
    }

    // MARK: - Properties

    private let label: String
    private let kind: Kind
    private let size: Size
    private let action: () -> Void

    // MARK: - Init

    /// Creates a BRU button.
    /// - Parameters:
    ///   - label: The button's display string. Rendered uppercase via `.textCase(.uppercase)`
    ///            at the view layer — source string stays as-typed for accessibility.
    ///   - kind: Visual treatment — `.primary` (default), `.signal`, or `.ghost`.
    ///   - size: Minimum height tier — `.sm` (32pt), `.md` (44pt, default), or `.lg` (52pt).
    ///   - action: Closure invoked on tap.
    public init(
        _ label: String,
        kind: Kind = .primary,
        size: Size = .md,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.kind = kind
        self.size = size
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(kind.textColor)
                .frame(maxWidth: .infinity, minHeight: size.minHeight)
                .background(kind.fillColor)
                .overlay(
                    // Only ghost variant renders the outline; primary + signal are solid fills.
                    Group {
                        if kind.showBorder {
                            Rectangle()
                                .stroke(kind.borderColor, lineWidth: 1.5)
                        }
                    }
                )
        }
        // CRITICAL: .plain suppresses Apple's bordered chrome (T-02.1-02-02).
        // If .plain is insufficient on a future iOS version, fall back to .borderless.
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUButton") {
    ScrollView {
        VStack(spacing: 24) {
            // Kind × Size matrix
            ForEach(["Primary", "Signal", "Ghost"], id: \.self) { kindName in
                let kind: BRUButton.Kind = kindName == "Primary" ? .primary
                                         : kindName == "Signal"  ? .signal
                                                                 : .ghost
                VStack(alignment: .leading, spacing: 8) {
                    Text(kindName)
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruMuted)

                    HStack(spacing: 8) {
                        BRUButton("Sm", kind: kind, size: .sm) {}
                        BRUButton("Medium", kind: kind, size: .md) {}
                        BRUButton("Large ▸", kind: kind, size: .lg) {}
                    }
                }
            }

            BRUDivider(.hair)

            // Practical examples
            VStack(alignment: .leading, spacing: 8) {
                Text("CTA examples")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)

                BRUButton("Start workout ▸", kind: .signal, size: .lg) {}
                BRUButton("Save routine ▸", kind: .primary, size: .md) {}
                BRUButton("Discard", kind: .ghost, size: .md) {}
            }
        }
        .padding(16)
    }
    .background(Color.bruPaper)
}
#endif
