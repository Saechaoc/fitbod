// BRUHeaderBar.swift
// fitbod — Phase 2.1 Plan 03
//
// Chrome primitive: replaces the default navigation bar with a 44pt BRU header.
// Every Phase 2.1 surface uses this instead of .navigationTitle / .toolbar.
//
// HEIGHT CONTRACT: 44pt content row + 2pt BRUDivider(.ink) = 46pt total.
// Downstream plans (02.1-04..09) must account for 46pt at the top of each surface.
// Do NOT nest BRUHeaderBar inside a NavigationStack that also has .navigationBarHidden(false).
//
// USAGE:
//   BRUHeaderBar(
//       left:   HeaderAction("‹ Back") { dismiss() },
//       center: "Edit Routine",
//       right:  HeaderAction("•••", isSignal: false) { showMenu() }
//   )

import SwiftUI

// MARK: - HeaderAction

/// A value type bundling a label, optional signal styling, and a tap action.
/// Define once per use-site; BRUHeaderBar holds it by value (no reference capture issues).
///
/// - Parameters:
///   - label:    Display text rendered in `BRUFont.labelSmall` UPPERCASE 1.2 letterspacing.
///   - isSignal: When `true`, the label renders in `Color.bruSignal` instead of `Color.bruInk`.
///   - action:   Closure invoked on tap. Use `@escaping` at the call site.
public struct HeaderAction: Sendable {
    public let label: String
    public let isSignal: Bool
    public let action: @Sendable () -> Void

    public init(_ label: String, isSignal: Bool = false, action: @escaping @Sendable () -> Void) {
        self.label = label
        self.isSignal = isSignal
        self.action = action
    }
}

// MARK: - BRUHeaderBar

/// Custom navigation bar replacement for the BRU design system.
///
/// Layout (top to bottom):
/// ```
/// ┌──────────────────────────────────────────┐  ← bruPaper fill
/// │  [left action]   [center title]  [right] │  44pt row
/// └──────────────────────────────────────────┘
/// ──────────────────────────────────────────────  2pt bruInk bottom rule
/// ```
///
/// Usage: mount at the top of a `VStack(spacing: 0)` on each surface, replacing
/// `.navigationTitle` calls. See UI-SPEC v2 §Component Inventory line 507.
public struct BRUHeaderBar: View {

    // MARK: State

    private let left: HeaderAction?
    private let center: String?
    private let right: HeaderAction?

    // MARK: Init

    public init(
        left: HeaderAction? = nil,
        center: String? = nil,
        right: HeaderAction? = nil
    ) {
        self.left = left
        self.center = center
        self.right = right
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left action — anchored leading, maxWidth to share space equally
                leftView
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Center title — anchored center, maxWidth to share space equally
                centerView
                    .frame(maxWidth: .infinity, alignment: .center)

                // Right action — anchored trailing, maxWidth to share space equally
                rightView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.bruPaper)

            // 2pt bruInk bottom rule per UI-SPEC v2 line 82
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var leftView: some View {
        if let left {
            actionButton(left)
        } else {
            Color.clear.frame(height: 44)
        }
    }

    @ViewBuilder
    private var centerView: some View {
        if let center {
            Text(center)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
        }
    }

    @ViewBuilder
    private var rightView: some View {
        if let right {
            actionButton(right)
        } else {
            Color.clear.frame(height: 44)
        }
    }

    private func actionButton(_ action: HeaderAction) -> some View {
        Button {
            action.action()
        } label: {
            Text(action.label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(action.isSignal ? Color.bruSignal : Color.bruInk)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("No actions") {
    VStack(spacing: 0) {
        BRUHeaderBar(center: "Today")
        Color.bruBg
    }
}

#Preview("Back + title") {
    VStack(spacing: 0) {
        BRUHeaderBar(
            left: HeaderAction("‹ Back") {},
            center: "Edit Routine"
        )
        Color.bruBg
    }
}

#Preview("Full — left / center / right (signal)") {
    VStack(spacing: 0) {
        BRUHeaderBar(
            left: HeaderAction("‹ Back") {},
            center: "Routines",
            right: HeaderAction("+ New", isSignal: true) {}
        )
        Color.bruBg
    }
}
#endif
