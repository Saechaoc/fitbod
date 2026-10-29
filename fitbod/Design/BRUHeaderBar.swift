// BRUHeaderBar.swift
// fitbod - Phase 2.1 Plan 03, unified in milestone 1
//
// Chrome primitive: replaces the default navigation bar with a BRU header.
// Every BRU surface uses this instead of .navigationTitle / .toolbar.
//
// HEIGHT CONTRACT: at least 44pt content row + 2pt bruInk rule = 46pt.
// The row grows past 44pt only when Dynamic Type makes the labels taller.
// Do NOT nest BRUHeaderBar inside a NavigationStack that also has .navigationBarHidden(false).
//
// Both APIs below render the same chrome: one row height, one title style
// (BRUFont.labelSmall, uppercase, 1.5 tracking) and the same action labels.
// Pass titles and labels in normal case ("Edit routine"); the bar uppercases
// them for display, so VoiceOver still reads words instead of letters.
//
// USAGE (HeaderAction API):
//   BRUHeaderBar(
//       left:   HeaderAction("‹ Back") { dismiss() },
//       center: "Edit routine",
//       right:  HeaderAction("•••") { showMenu() }
//   )
//
// USAGE (HeaderSlot API via the BRUHeaderBar.slots factory):
//   BRUHeaderBar.slots(
//       left:   .back,
//       center: "Block · Upper Hyp",
//       right:  .action("Edit") { edit() }
//   )
//
// NOTE on overload disambiguation: a HeaderAction? init and a HeaderSlot? init would be
// ambiguous when only `center:` is provided (Swift can't choose between two identical-label
// overloads with nil-defaulted params). The `.slots(...)` static factory avoids this.

import SwiftUI

// MARK: - HeaderAction

/// A value type bundling a label, optional signal styling, and a tap action.
/// Define once per use-site; BRUHeaderBar holds it by value (no reference capture issues).
///
/// - Parameters:
///   - label:    Display text, rendered in `BRUFont.labelSmall` uppercase with 1.5 tracking.
///   - isSignal: When `true`, the label renders in `Color.bruSignal` instead of `Color.bruInk`.
///   - action:   Closure invoked on tap.
public struct HeaderAction {
    public let label: String
    public let isSignal: Bool
    /// Nil renders a plain label with no tap action (see `text(_:)`).
    public let action: (@MainActor () -> Void)?

    public init(_ label: String, isSignal: Bool = false, action: @escaping @MainActor () -> Void) {
        self.label = label
        self.isSignal = isSignal
        self.action = action
    }

    private init(text: String) {
        self.label = text
        self.isSignal = false
        self.action = nil
    }

    /// A plain, non-tappable label, such as today's date. VoiceOver reads it
    /// as text, not as a button.
    public static func text(_ label: String) -> HeaderAction {
        HeaderAction(text: label)
    }
}

// MARK: - HeaderSlot

/// Slot descriptor for the enum-based `BRUHeaderBar.slots` factory.
///
/// Cases:
/// - `.back`: Renders "‹ Back" in bruInk. On tap, invokes SwiftUI's environment `dismiss`.
/// - `.cancel`: Renders "Cancel" in bruInk. On tap, invokes SwiftUI's environment `dismiss`.
/// - `.action(String, () -> Void)`: Renders the label in bruSignal with a tap closure.
/// - `.text(String)`: Renders the label in bruInk with no tap action.
/// - `.empty`: Renders nothing (equivalent to passing `nil`).
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
/// │  [left action]   [CENTER TITLE]  [right] │  ≥ 44pt row
/// └──────────────────────────────────────────┘
/// ──────────────────────────────────────────────  2pt bruInk bottom rule
/// ```
///
/// Two usage forms with identical rendering:
/// - **HeaderAction init**: `BRUHeaderBar(left: HeaderAction("‹ Back") {}, center: "Title")`.
/// - **HeaderSlot factory**: `BRUHeaderBar.slots(left: .back, center: "Title")`.
///   `.back` / `.cancel` auto-wire dismiss; `.action(label, closure)` renders in bruSignal.
///
/// Usage: mount at the top of a `VStack(spacing: 0)` on each surface, replacing
/// `.navigationTitle` calls.
public struct BRUHeaderBar: View {

    // MARK: Mode

    private enum Mode {
        case actions(left: HeaderAction?, center: String?, right: HeaderAction?)
        case slots(left: HeaderSlot?, center: String?, right: HeaderSlot?)
    }

    private let mode: Mode

    // MARK: Init (HeaderAction)

    public init(
        left: HeaderAction? = nil,
        center: String? = nil,
        right: HeaderAction? = nil
    ) {
        self.mode = .actions(left: left, center: center, right: right)
    }

    // Internal init used by the .slots factory
    private init(slotLeft: HeaderSlot?, center: String?, slotRight: HeaderSlot?) {
        self.mode = .slots(left: slotLeft, center: center, right: slotRight)
    }

    // MARK: Factory (HeaderSlot)
    //
    // A static factory rather than an additional init, to avoid Swift overload
    // ambiguity: init(left: HeaderAction?, center:, right: HeaderAction?) and
    // init(left: HeaderSlot?, center:, right: HeaderSlot?) have identical labels
    // and would make calls like BRUHeaderBar(center: "Title") ambiguous.

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
        case .actions(let left, let center, let right):
            BRUHeaderChrome(center: center) {
                if let left { HeaderActionView(item: left) }
            } right: {
                if let right { HeaderActionView(item: right) }
            }
        case .slots(let left, let center, let right):
            BRUHeaderChrome(center: center) {
                SlotView(slot: left)
            } right: {
                SlotView(slot: right)
            }
        }
    }
}

// MARK: - Shared metrics

private enum BRUHeaderMetrics {
    static let minRowHeight: CGFloat = 44
    static let ruleHeight: CGFloat = 2
    static let horizontalPadding: CGFloat = 16
    static let tracking: CGFloat = 1.5
}

// MARK: - BRUHeaderChrome (shared by both APIs)

/// Three equal columns so the title stays centred whatever the side labels are.
private struct BRUHeaderChrome<Left: View, Right: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let center: String?
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        centerView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        HStack {
                            left
                            Spacer(minLength: 12)
                            right
                        }
                    }
                } else {
                    standardRow
                }
            }
            .padding(.horizontal, BRUHeaderMetrics.horizontalPadding)
            .frame(minHeight: BRUHeaderMetrics.minRowHeight)
            .background(Color.bruPaper)

            Rectangle()
                .fill(Color.bruInk)
                .frame(height: BRUHeaderMetrics.ruleHeight)
        }
    }

    private var standardRow: some View {
        HStack(spacing: 0) {
                // Each side sits next to a Spacer so its column keeps its
                // third of the row even when the side is empty. A frame on
                // an empty view collapses to nothing and would pull the
                // title off centre.
                HStack(spacing: 0) {
                    left
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                centerView
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    right
                }
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var centerView: some View {
        if let center {
            Text(center)
                .font(BRUFont.labelSmall)
                .tracking(BRUHeaderMetrics.tracking)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : (center.contains(" ") ? 2 : 1))
                .minimumScaleFactor(center.contains(" ") ? 0.85 : 0.65)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: - Labels

/// A `HeaderAction`: a button when it has an action, plain text otherwise.
private struct HeaderActionView: View {

    let item: HeaderAction

    var body: some View {
        if let action = item.action {
            HeaderLabelButton(label: item.label, isSignal: item.isSignal, action: action)
        } else {
            HeaderLabelText(label: item.label, isSignal: item.isSignal)
        }
    }
}

/// One tappable header label. The visible text stays small; `bruHitArea()`
/// keeps the touch target comfortable without moving the layout.
private struct HeaderLabelButton: View {

    let label: String
    let isSignal: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HeaderLabelText(label: label, isSignal: isSignal)
                .bruHitArea()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.spokenLabel(for: label))
    }

    /// Glyph-only labels get a word, so VoiceOver says "Back" rather than
    /// "single left-pointing angle quotation mark".
    static func spokenLabel(for label: String) -> String {
        switch label.trimmingCharacters(in: .whitespaces) {
        case "‹", "‹ Back": return "Back"
        case "•••":         return "More"
        case "×", "✕":      return "Close"
        default:            return label
        }
    }
}

private struct HeaderLabelText: View {

    let label: String
    let isSignal: Bool

    var body: some View {
        Text(label)
            .font(BRUFont.labelSmall)
            .tracking(BRUHeaderMetrics.tracking)
            .textCase(.uppercase)
            .foregroundStyle(isSignal ? Color.bruSignalText : Color.bruInk)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

private struct SlotView: View {

    @Environment(\.dismiss) private var dismiss

    let slot: HeaderSlot?

    var body: some View {
        switch slot {
        case .back:
            HeaderLabelButton(label: "‹ Back", isSignal: false) { dismiss() }
                .accessibilityLabel("Back")

        case .cancel:
            HeaderLabelButton(label: "Cancel", isSignal: false) { dismiss() }

        case .action(let label, let action):
            HeaderLabelButton(label: label, isSignal: true, action: action)

        case .text(let label):
            HeaderLabelText(label: label, isSignal: false)

        case .empty, nil:
            EmptyView()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Title only") {
    VStack(spacing: 0) {
        BRUHeaderBar(center: "Today")
        Color.bruBg
    }
}

#Preview("Back + title") {
    VStack(spacing: 0) {
        BRUHeaderBar(
            left: HeaderAction("‹ Back") {},
            center: "Edit routine"
        )
        Color.bruBg
    }
}

#Preview("Back + title + signal action") {
    VStack(spacing: 0) {
        BRUHeaderBar(
            left: HeaderAction("‹ Back") {},
            center: "Routines",
            right: HeaderAction("+ New", isSignal: true) {}
        )
        Color.bruBg
    }
}

#Preview("Slots: back, long title, action") {
    VStack(spacing: 0) {
        BRUHeaderBar.slots(
            left: .back,
            center: "Block · Upper Hypertrophy",
            right: .action("Edit") {}
        )
        BRUHeaderBar.slots(left: .cancel, center: "Add phase", right: .text("2 / 4"))
        Color.bruBg
    }
}

#Preview("Slots at accessibility text size") {
    VStack(spacing: 0) {
        BRUHeaderBar.slots(left: .back, center: "Routine", right: .action("Done") {})
        Color.bruBg
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
