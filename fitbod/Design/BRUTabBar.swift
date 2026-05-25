// BRUTabBar.swift
// fitbod — Phase 2.1 Plan 03
//
// Chrome primitive: replaces the SwiftUI default TabView tab bar chrome.
//
// WIRING NOTE (threat T-02.1-03-01):
//   Use BRUTabBar via `.safeAreaInset(edge: .bottom)` on the TabView, combined
//   with `.toolbarBackground(.hidden, for: .tabBar)` to hide the default bar.
//   NEVER wrap the TabView in a parent NavigationStack (UI-SPEC v2 line 58).
//   Plan 02.1-04 wires this into RootView.
//
// TAB COUNT: 4 tabs (today / routines / progress / settings).
//   Library was removed in quick task 260525-g32 follow-up — the exercise
//   library is reachable from the routine builder; a dedicated tab was
//   redundant. Settings preserved.
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
    case routines
    case progress
    case settings

    /// Human-readable tab label rendered in `BRUFont.labelSmall` UPPERCASE.
    public var label: String {
        switch self {
        case .today:    return "Today"
        case .routines: return "Routines"
        case .progress: return "Progress"
        case .settings: return "Settings"
        }
    }

    /// Typographic glyph rendered above the label.
    /// Uses Unicode block-element characters; not SF Symbols.
    public var glyph: String {
        switch self {
        case .today:    return "▣"
        case .routines: return "▤"
        case .progress: return "▦"
        case .settings: return "◍"
        }
    }
}

// MARK: - BRUTabBar

/// Full-bleed replacement for the SwiftUI default tab bar chrome.
///
/// Layout (top to bottom):
/// ```
/// ──────────────────────────────────────────────  2pt bruInk top rule
/// ┌──────┬──────┬──────┬──────┐
/// │TODAY │ROUT. │PROG. │SETT. │  56pt min cell height
/// └──────┴──────┴──────┴──────┘
/// ```
/// Labels-only — the JSX mocks in `bru-screens/` show no glyphs above
/// the labels. The `BRUTab.glyph` property is retained for potential
/// reuse elsewhere but is no longer rendered in the bar.
/// Active tab: bruInk fill, bruTabSurface text.
/// Inactive tabs: bruTabSurface fill, bruInk text.
/// 1pt bruTabSeparator vertical separators between cells.
/// The whole bar paints `bruTabSurface` through the bottom safe-area
/// via `ignoresSafeArea(.container, edges: .bottom)` so it reads as a
/// full-bleed bar pinned to the screen edge (no "floating pill" gap
/// above the home indicator).
///
/// Accessibility: each cell carries `.isButton`. The active cell additionally
/// carries `.isSelected` per UI-SPEC v2 line 689 so VoiceOver announces
/// "selected" on the active tab.
public struct BRUTabBar: View {

    // MARK: Properties

    private let active: BRUTab
    private let onSelect: @Sendable (BRUTab) -> Void

    // MARK: Init

    public init(active: BRUTab, onSelect: @escaping @Sendable (BRUTab) -> Void) {
        self.active = active
        self.onSelect = onSelect
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            // 2pt bruInk top rule per UI-SPEC v2 line 82
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)

            HStack(spacing: 0) {
                ForEach(BRUTab.allCases, id: \.rawValue) { tab in
                    tabCell(tab)

                    // 1pt cool-gray separator between cells (not after the last one)
                    if tab != BRUTab.allCases.last {
                        Rectangle()
                            .fill(Color.bruTabSeparator)
                            .frame(width: 1)
                    }
                }
            }
        }
        // Paint the tab surface through the bottom safe area so the bar
        // reads as a full-bleed rectangle pinned to the screen edge —
        // eliminates the "floating pill" gap above the home indicator.
        .background(
            Color.bruTabSurface
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    // MARK: Cell

    @ViewBuilder
    private func tabCell(_ tab: BRUTab) -> some View {
        let isActive = tab == active

        Button {
            onSelect(tab)
        } label: {
            Text(tab.label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(isActive ? Color.bruInk : Color.bruTabSurface)
                .foregroundStyle(isActive ? Color.bruTabSurface : Color.bruInk)
        }
        .buttonStyle(.plain)
        // Accessibility: .isSelected on the active tab per UI-SPEC v2 line 689
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
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

#Preview("Active: Routines") {
    VStack {
        Spacer()
        BRUTabBar(active: .routines) { _ in }
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

#Preview("Active: Settings") {
    VStack {
        Spacer()
        BRUTabBar(active: .settings) { _ in }
    }
    .background(Color.bruBg)
}
#endif
