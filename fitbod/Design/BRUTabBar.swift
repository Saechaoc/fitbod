// BRUTabBar.swift
// fitbod — Phase 2.1 Plan 03
//
// Chrome primitive: replaces the SwiftUI default TabView tab bar chrome.
//
// WIRING NOTE (threat T-02.1-03-01):
//   RootView uses native TabView containment with system chrome hidden,
//   then adds BRUTabBar. Each tab owns its NavigationStack; never wrap the tabs
//   in a parent NavigationStack (UI-SPEC v2 line 58).
//   RootView hides the bar while the software keyboard is up, so the bar
//   never rides up over the field being edited, and while the selected
//   tab's visible screen applies `.bruTabBarHidden()` (the workout logger).
//
// TAB COUNT: 4 tabs (today / program / progress / library).
//   Settings is not a tab. It is a sheet opened by the "Settings" button
//   in the Today header.
//   `program` replaces the former `routines` tab (quick task 260525-gen) -
//   the Routines surface was rebranded as Program to reflect block/
//   periodization as the primary planning unit; the underlying Routine
//   data model is unchanged.
//
// USAGE:
//   BRUTabBar(active: .today) { tab in selectedTab = tab }

import SwiftUI

// MARK: - BRUTab Enum

/// The four top-level destinations in the BRU tab bar.
///
/// Typographic glyphs are Unicode box-drawing characters — NO SF Symbols.
/// Per UI-SPEC v2 §Design System: "SF Symbols are NOT used in BRU."
public enum BRUTab: String, CaseIterable, Sendable {
    case today
    case program
    case progress
    case library

    /// Human-readable tab label rendered in `BRUFont.labelSmall` UPPERCASE.
    public var label: String {
        switch self {
        case .today:    return "Today"
        case .program:  return "Program"
        case .progress: return "Progress"
        case .library:  return "Library"
        }
    }

    /// Typographic glyph rendered above the label.
    /// Uses Unicode block-element characters; not SF Symbols.
    public var glyph: String {
        switch self {
        case .today:    return "▣"
        case .program:  return "▤"
        case .progress: return "▦"
        case .library:  return "▥"
        }
    }
}

// MARK: - BRUTabBar

/// Full-bleed replacement for the SwiftUI default tab bar chrome.
///
/// Layout (top to bottom): 2pt ink rule, a compact 61pt label band,
/// and a negative bottom inset so the rendered bar occupies the same
/// 63pt bottom chrome block as `bru-screens/Program/empty-state.png`.
/// Labels-only — the JSX mocks in `bru-screens/` show no glyphs above
/// the labels. The `BRUTab.glyph` property is retained for potential
/// reuse elsewhere but is no longer rendered in the bar.
/// Active tab: bruInk fill, bruPaper text. Inactive tabs sit directly
/// on the warm `bruBg` surface with no vertical separators.
///
/// Accessibility: each cell carries `.isButton`. The active cell additionally
/// carries `.isSelected` per UI-SPEC v2 line 689 so VoiceOver announces
/// "selected" on the active tab.
public struct BRUTabBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Properties

    private let active: BRUTab
    private let onSelect: @MainActor (BRUTab) -> Void

    private static let mockupTopRuleHeight: CGFloat = 2
    private static let mockupCellHeight: CGFloat = 61
    private static let mockupSelectedHeight: CGFloat = 29
    private static let mockupSelectedTopInset: CGFloat = 8
    private static let mockupBottomSafeOverlap: CGFloat = 34

    // MARK: Init

    public init(active: BRUTab, onSelect: @escaping @MainActor (BRUTab) -> Void) {
        self.active = active
        self.onSelect = onSelect
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: Self.mockupTopRuleHeight)

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                    ForEach(BRUTab.allCases, id: \.rawValue) { tab in
                        tabCell(tab)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(BRUTab.allCases, id: \.rawValue) { tab in
                        tabCell(tab)
                    }
                }
                .frame(height: Self.mockupCellHeight)
            }
        }
        .background(
            Color.bruBg
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 0 : -Self.mockupBottomSafeOverlap)
    }

    // MARK: Cell

    @ViewBuilder
    private func tabCell(_ tab: BRUTab) -> some View {
        let isActive = tab == active

        Button {
            onSelect(tab)
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                Text(tab.label)
                    .font(.bru(.grotesk, size: 10))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    // A color background ignores the safe area by default, so
                    // the bottom row would paint into the home indicator area.
                    // Stop at the cell.
                    .background(isActive ? Color.bruInk : Color.bruBg, ignoresSafeAreaEdges: [])
                    .contentShape(Rectangle())
            } else {
            ZStack(alignment: .top) {
                if isActive {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(height: Self.mockupSelectedHeight)
                        .padding(.top, Self.mockupSelectedTopInset)
                }

                Text(tab.label)
                    .font(.bru(.grotesk, size: 10))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isActive ? Color.bruPaper : Color.bruInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.mockupSelectedHeight)
                    .padding(.top, Self.mockupSelectedTopInset)
            }
            .frame(height: Self.mockupCellHeight, alignment: .top)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(tab.label)
        // Accessibility: .isSelected on the active tab per UI-SPEC v2 line 689
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Hiding the bar

/// True when a screen asks `RootView` to hide the tab bar. Any `true` in
/// the selected tab's visible hierarchy wins.
struct BRUTabBarHiddenKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Hides the bottom tab bar while this screen is on screen. For screens
    /// that need the full height and lead back out with their own header,
    /// such as the workout logger.
    func bruTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: BRUTabBarHiddenKey.self, value: hidden)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Active: Today") {
    VStack {
        Spacer()
        BRUTabBar(active: .today) { _ in }
    }
    .background(Color.bruBg)
}

#Preview("Active: Program") {
    VStack {
        Spacer()
        BRUTabBar(active: .program) { _ in }
    }
    .background(Color.bruBg)
}

#Preview("Active: Progress") {
    VStack {
        Spacer()
        BRUTabBar(active: .progress) { _ in }
    }
    .background(Color.bruBg)
}

#Preview("Active: Library") {
    VStack {
        Spacer()
        BRUTabBar(active: .library) { _ in }
    }
    .background(Color.bruBg)
}
#endif
