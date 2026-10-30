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
/// - `.signal`  — signal fill, constant ink text (strong CTA)
/// - `.ghost`   — transparent fill, ink text, 1.5pt ink outline
///
/// Three `Size` variants provide at least BRU's 44pt touch-target floor.
///
/// `.buttonStyle(.plain)` is mandatory — it suppresses Apple's default bordered
/// and borderless chrome tinting that would violate the BRU contract (T-02.1-02-02).
public struct BRUButton: View {

    // MARK: - Kind

    /// The visual treatment variant of the button.
    public enum Kind {
        /// Ink fill with paper text — default strong action.
        case primary
        /// Signal fill with constant ink text — the primary CTA per screen.
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
            case .primary: return .bruPaper
            case .signal:  return .bruOnSignal
            case .ghost:   return .bruInk
            }
        }

        fileprivate var borderColor: Color {
            switch self {
            case .primary: return .bruInk
            case .signal:  return .bruInk
            case .ghost:   return .bruInk
            }
        }

        fileprivate var showBorder: Bool {
            switch self {
            case .primary: return false
            case .signal, .ghost: return true
            }
        }
    }

    // MARK: - Size

    /// The vertical size tier of the button.
    public enum Size {
        /// 44pt minimum height — compact typography, comfortable touch target.
        case sm
        /// 44pt minimum height — standard tappable controls (iOS HIG touch target).
        case md
        /// 52pt minimum height — prominent full-width CTAs.
        case lg

        /// Minimum height for the button's frame.
        public var minHeight: CGFloat {
            switch self {
            case .sm, .md: return BRUMetrics.touchTarget
            case .lg: return BRUMetrics.primaryActionHeight
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
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
        }
        // BRUButtonStyle replaces `.plain`: it keeps Apple's chrome off while
        // adding a full-rectangle hit area plus pressed and disabled states.
        .buttonStyle(BRUButtonStyle(kind: kind, size: size))
    }
}

// MARK: - BRUButtonStyle

/// Renders a `BRUButton` in its three interaction states.
///
/// - Normal: the kind's fill, text and border.
/// - Pressed: fills darken to `bruInk` (ghost inverts to an ink slab) so the
///   press reads on every kind without animation.
/// - Disabled: `bruFaint` fill, `bruMuted` text, `bruHair` border. Text stays
///   legible (contrast ≥ 4.5:1) instead of fading the whole control.
///
/// The whole frame is hit-testable (`contentShape`), so a ghost button
/// responds outside its label too.
public struct BRUButtonStyle: ButtonStyle {
    let kind: BRUButton.Kind
    let size: BRUButton.Size
    let fill: Color?

    public init(kind: BRUButton.Kind, size: BRUButton.Size, fill: Color? = nil) {
        self.kind = kind
        self.size = size
        self.fill = fill
    }

    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(size.font)
            .tracking(size.tracking)
            .foregroundStyle(textColor(pressed: pressed))
            .padding(.horizontal, BRUMetrics.Spacing.group)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: size.minHeight)
            // A color background ignores the safe area by default, so a button
            // on the home indicator area would paint into it. Stop at the frame.
            .background(fillColor(pressed: pressed), ignoresSafeAreaEdges: [])
            .overlay(
                Rectangle()
                    .strokeBorder(borderColor, lineWidth: showBorder ? BRUMetrics.Border.outline : 0)
            )
            .contentShape(Rectangle())
    }

    private var showBorder: Bool {
        kind.showBorder || !isEnabled
    }

    private var borderColor: Color {
        isEnabled ? kind.borderColor : .bruHair
    }

    private func fillColor(pressed: Bool) -> Color {
        guard isEnabled else { return .bruFaint }
        guard pressed else { return fill ?? kind.fillColor }
        return kind == .ghost ? .bruInk : .bruInk.opacity(0.85)
    }

    private func textColor(pressed: Bool) -> Color {
        guard isEnabled else { return .bruMuted }
        if pressed { return .bruPaper }
        return fill?.bruLabelOnFill ?? kind.textColor
    }
}

extension BRUButton.Size {
    /// Label font grows with the button so large CTAs read at arm's length.
    var font: Font {
        switch self {
        case .sm: return BRUFont.labelSmall
        case .md: return BRUFont.labelLarge
        case .lg: return BRUFont.displayMedium
        }
    }

    var tracking: CGFloat {
        switch self {
        case .sm: return 1.2
        case .md: return 1.4
        case .lg: return 0.6
        }
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
