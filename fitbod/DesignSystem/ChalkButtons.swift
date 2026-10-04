//
//  ChalkButtons.swift
//  fitbod
//
//  Chalkline buttons. One `ButtonStyle` with five kinds covers every
//  action in the milestone; `ChalkIconButton` covers icon-only actions
//  (always with an accessibility label).
//
//  Usage rules (docs/design-system/README.md § Buttons):
//    - `.primary` (accent fill, ink label) — at most one per view region:
//      Start workout, Save, Finish, Resume.
//    - `.secondary` (paper fill, ink outline) — Add set, Add exercises,
//      Clear filters.
//    - `.inverse` (iron fill) — strong non-primary actions (Done on a
//      summary, Finish in the workout toolbar).
//    - `.ghost` (accent-ink text) — low-emphasis actions inside cards.
//    - `.destructive` (danger outline) — Discard, Delete. Always confirmed.
//    - `.onPanel` (raised iron) — controls that sit on a panel (±15 s).
//
//  States: pressed = 10% ink overlay + 0.97 scale (scale skipped under
//  Reduce Motion); disabled = 45% opacity (prefer inline validation over
//  disabling); focus = system focus ring.
//

import SwiftUI

public struct ChalkButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        case primary
        case secondary
        case inverse
        case ghost
        case destructive
        case onPanel
    }

    public enum Size: Sendable {
        /// 44 pt — inline / toolbar.
        case compact
        /// 50 pt — default.
        case regular
        /// 56 pt — thumb-zone primary bars.
        case large
    }

    public var kind: Kind
    public var size: Size
    public var fullWidth: Bool

    public init(_ kind: Kind = .primary, size: Size = .regular, fullWidth: Bool = false) {
        self.kind = kind
        self.size = size
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        ChalkButtonBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == ChalkButtonStyle {
    /// `.buttonStyle(.chalk(.primary, size: .large, fullWidth: true))`
    public static func chalk(
        _ kind: ChalkButtonStyle.Kind = .primary,
        size: ChalkButtonStyle.Size = .regular,
        fullWidth: Bool = false
    ) -> ChalkButtonStyle {
        ChalkButtonStyle(kind, size: size, fullWidth: fullWidth)
    }
}

private struct ChalkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: ChalkButtonStyle.Kind
    let size: ChalkButtonStyle.Size
    let fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
        configuration.label
            .font(.chalkButton)
            .textCase(.uppercase)
            .tracking(Chalk.Tracking.button)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, Chalk.Space.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: minHeight)
            .background(fill, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: borderWidth)
            }
            .overlay {
                if configuration.isPressed {
                    shape.fill(Color.chalkInk.opacity(kind == .ghost ? 0.06 : 0.10))
                }
            }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: Chalk.Motion.quick), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var minHeight: CGFloat {
        switch size {
        case .compact: return Chalk.Size.minTouch
        case .regular: return Chalk.Size.button
        case .large: return Chalk.Size.primaryBar
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: return Chalk.Space.md
        case .regular: return Chalk.Space.lg
        case .large: return Chalk.Space.xl
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .chalkOnAccent
        case .secondary: return .chalkInk
        case .inverse: return .chalkCanvas
        case .ghost: return .chalkAccentInk
        case .destructive: return .chalkDanger
        case .onPanel: return .chalkOnPanel
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return .chalkAccent
        case .secondary: return .chalkSurface
        case .inverse: return .chalkInk
        case .ghost: return .clear
        case .destructive: return .chalkSurface
        case .onPanel: return .chalkPanelRaised
        }
    }

    private var border: Color {
        switch kind {
        case .secondary: return .chalkInk
        case .destructive: return .chalkDanger
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch kind {
        case .secondary, .destructive: return Chalk.Line.strong
        default: return 0
        }
    }
}

// MARK: - Icon button

/// Icon-only, 44 × 44 button. `accessibilityLabel` is required by
/// construction so no icon button ships unlabeled.
public struct ChalkIconButton: View {
    public enum Style: Sendable {
        /// Paper circle with an ink outline (toolbar-like actions in content).
        case outlined
        /// No chrome (row accessories, menus).
        case plain
        /// Raised iron square for use on panels.
        case onPanel
    }

    let systemImage: String
    let a11yLabel: String
    let style: Style
    let action: () -> Void

    public init(
        _ systemImage: String,
        accessibilityLabel: String,
        style: Style = .plain,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.a11yLabel = accessibilityLabel
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ChalkIconGlyph(systemImage: systemImage, style: style)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(a11yLabel))
    }
}

/// The visual for `ChalkIconButton`, reusable as a `Menu` label so menus
/// and buttons share one look.
public struct ChalkIconGlyph: View {
    let systemImage: String
    let style: ChalkIconButton.Style

    public init(systemImage: String, style: ChalkIconButton.Style = .plain) {
        self.systemImage = systemImage
        self.style = style
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: Chalk.Size.minTouch, height: Chalk.Size.minTouch)
            .background {
                switch style {
                case .outlined:
                    Circle()
                        .fill(Color.chalkSurface)
                        .overlay { Circle().strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.strong) }
                case .plain:
                    Color.clear
                case .onPanel:
                    RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous)
                        .fill(Color.chalkPanelRaised)
                }
            }
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        style == .onPanel ? .chalkOnPanel : .chalkInk
    }
}

#Preview("Buttons") {
    ScrollView {
        VStack(spacing: Chalk.Space.md) {
            Button {} label: { Label("Start workout", systemImage: "play.fill") }
                .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
            Button("Add set") {}
                .buttonStyle(.chalk(.secondary, fullWidth: true))
            HStack {
                Button("Inverse") {}.buttonStyle(.chalk(.inverse))
                Button("Ghost") {}.buttonStyle(.chalk(.ghost))
                Button("Discard") {}.buttonStyle(.chalk(.destructive))
            }
            Button("Disabled") {}
                .buttonStyle(.chalk(.primary, fullWidth: true))
                .disabled(true)
            HStack {
                ChalkIconButton("plus", accessibilityLabel: "Add", style: .outlined) {}
                ChalkIconButton("ellipsis", accessibilityLabel: "More") {}
            }
        }
        .padding()
    }
    .background(Color.chalkCanvas)
}
