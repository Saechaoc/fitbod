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
// USAGE (legacy — HeaderAction struct API, all existing callers):
//   BRUHeaderBar(
//       left:   HeaderAction("‹ Back") { dismiss() },
//       center: "Edit Routine",
//       right:  HeaderAction("•••", isSignal: false) { showMenu() }
//   )
//
// USAGE (Phase 04.1 — HeaderSlot enum API via BRUHeaderBar.slots factory):
//   BRUHeaderBar.slots(
//       left:   .back,
//       center: "Block · Upper Hyp",
//       right:  .action("EDIT") { edit() }
//   )
//
// NOTE on overload disambiguation: the HeaderAction? init and a HeaderSlot? init would be
// ambiguous when only `center:` is provided (Swift can't choose between two identical-label
// overloads with nil-defaulted params). The `.slots(...)` static factory avoids this.

import SwiftUI

// MARK: - HeaderAction (legacy API — all existing callers use this)

/// A value type bundling a label, optional signal styling, and a tap action.
/// Define once per use-site; BRUHeaderBar holds it by value (no reference capture issues).
///
/// - Parameters:
///   - label:    Display text rendered in `BRUFont.labelSmall` UPPERCASE 1.2 letterspacing.
///   - isSignal: When `true`, the label renders in `Color.bruSignal` instead of `Color.bruInk`.
///   - action:   Closure invoked on tap. Use `@escaping` at the call site.
public struct HeaderAction {
    public let label: String
    public let isSignal: Bool
    public let action: @MainActor () -> Void

    public init(_ label: String, isSignal: Bool = false, action: @escaping @MainActor () -> Void) {
        self.label = label
        self.isSignal = isSignal
        self.action = action
    }
}

// MARK: - HeaderSlot (Phase 04.1 API)

/// Slot descriptor for the enum-based BRUHeaderBar factory used in Phase 04.1 surfaces.
///
/// Cases:
/// - `.back`: Renders the `‹` glyph in bruInk. On tap, invokes SwiftUI's environment `dismiss`.
/// - `.cancel`: Renders "CANCEL" text in bruInk. On tap, invokes SwiftUI's environment `dismiss`.
/// - `.action(String, () -> Void)`: Renders the label string in bruSignal with a tap closure.
/// - `.text(String)`: Renders the label string in bruInk with no tap action.
/// - `.empty`: Renders nothing (equivalent to passing `nil` to the legacy `HeaderAction?` API).
public enum HeaderSlot {
    case back
    case cancel
    case action(String, @MainActor () -> Void)
    case text(String)
    case empty
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
/// Two usage forms:
/// - **Legacy init** (`HeaderAction?` params): `BRUHeaderBar(left: HeaderAction("‹") {}, center: "Title")`.
///   Used by all pre-04.1 callers. Maintains exact backward compatibility.
/// - **Phase 04.1 factory** (`HeaderSlot?` params): `BRUHeaderBar.slots(left: .back, center: "Title")`.
///   `.back` / `.cancel` auto-wire dismiss; `.action(label, closure)` renders in bruSignal.
///   Uses a static factory to avoid Swift overload ambiguity with the legacy init.
///
/// Usage: mount at the top of a `VStack(spacing: 0)` on each surface, replacing
/// `.navigationTitle` calls. See UI-SPEC v2 §Component Inventory line 507.
public struct BRUHeaderBar: View {

    // MARK: Mode

    private enum Mode {
        case legacy(left: HeaderAction?, center: String?, right: HeaderAction?)
        case slots(left: HeaderSlot?, center: String?, right: HeaderSlot?)
    }

    private let mode: Mode

    // MARK: Init — Legacy (HeaderAction)

    public init(
        left: HeaderAction? = nil,
        center: String? = nil,
        right: HeaderAction? = nil
    ) {
        self.mode = .legacy(left: left, center: center, right: right)
    }

    // Internal init used by the .slots factory
    private init(slotLeft: HeaderSlot?, center: String?, slotRight: HeaderSlot?) {
        self.mode = .slots(left: slotLeft, center: center, right: slotRight)
    }

    // MARK: Factory — Phase 04.1 (HeaderSlot)
    //
    // Implemented as a static factory method rather than an additional init to avoid
    // Swift overload ambiguity: both init(left: HeaderAction?, center: String?, right: HeaderAction?)
    // and init(left: HeaderSlot?, center: String?, right: HeaderSlot?) have identical labels
    // and would produce an "ambiguous use" error for calls like BRUHeaderBar(center: "Title").
    //
    // Phase 04.1 call sites use:
    //   BRUHeaderBar.slots(left: .back, center: "Block · Upper Hyp", right: .action("EDIT") {...})

    public static func slots(
        left: HeaderSlot? = nil,
        center: String? = nil,
        right: HeaderSlot? = nil
    ) -> BRUHeaderBar {
        BRUHeaderBar(slotLeft: left, center: center, slotRight: right)
    }

    // MARK: Body

    public var body: some View {
        switch mode {
        case .legacy(let left, let center, let right):
            LegacyBRUHeaderBarBody(left: left, center: center, right: right)
        case .slots(let left, let center, let right):
            SlotBRUHeaderBarBody(left: left, center: center, right: right)
        }
    }
}

// MARK: - LegacyBRUHeaderBarBody (internal — legacy HeaderAction API)

private struct LegacyBRUHeaderBarBody: View {

    let left: HeaderAction?
    let center: String?
    let right: HeaderAction?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leftView
                    .frame(maxWidth: .infinity, alignment: .leading)
                centerView
                    .frame(maxWidth: .infinity, alignment: .center)
                rightView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.bruPaper)

            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

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

// MARK: - SlotBRUHeaderBarBody (internal — Phase 04.1 HeaderSlot API)

private struct SlotBRUHeaderBarBody: View {

    @Environment(\.dismiss) private var dismiss

    let left: HeaderSlot?
    let center: String?
    let right: HeaderSlot?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                slotView(left)
                    .frame(maxWidth: .infinity, alignment: .leading)
                centerView
                    .frame(maxWidth: .infinity, alignment: .center)
                slotView(right)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(Color.bruPaper)

            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    @ViewBuilder
    private var centerView: some View {
        if let center {
            Text(center)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
        }
    }

    @ViewBuilder
    private func slotView(_ slot: HeaderSlot?) -> some View {
        switch slot {
        case .back:
            Button {
                dismiss()
            } label: {
                Text("‹")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .foregroundStyle(Color.bruInk)
            }
            .buttonStyle(.plain)

        case .cancel:
            Button {
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
            }
            .buttonStyle(.plain)

        case .action(let label, let action):
            Button {
                action()
            } label: {
                Text(label)
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }
            .buttonStyle(.plain)

        case .text(let label):
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)

        case .empty, nil:
            Color.clear.frame(height: 44)
        }
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

#Preview("Phase 04.1 — HeaderSlot API via .slots factory") {
    VStack(spacing: 0) {
        BRUHeaderBar.slots(
            left: .back,
            center: "Block · Upper Hyp",
            right: .action("EDIT") {}
        )
        Color.bruBg
    }
}
#endif
