---
quick_id: 260524-ilf
slug: wire-brutabbar-into-rootview
date: 2026-05-24
status: in-progress
---

# Quick Task 260524-ilf: Wire BRUTabBar into RootView

## Description

Replace the default SwiftUI `TabView` chrome in `RootView` with the
existing `BRUTabBar` component. The component shipped in Phase 02.1-03
(`fitbod/Design/BRUTabBar.swift:77`) but was never wired into the app —
`RootView.swift:161` still renders the system tab bar with SF Symbols.

This is the first incremental step of the BRU visual rewrite restart.
Scope is intentionally narrow: bottom nav chrome only. Screen bodies
stay untouched.

## Tasks

1. **Hide default tab bar chrome.** Apply
   `.toolbarBackground(.hidden, for: .tabBar)` to the `TabView` in
   `RootView.swift`. Without this the system bar paints behind/over the
   BRU bar.

2. **Mount BRUTabBar via `.safeAreaInset(edge: .bottom)`.** Per the
   wiring note in `BRUTabBar.swift:7-9`, this is the supported pattern.
   The `TabView` controls which tab body renders; `BRUTabBar` is purely
   chrome that drives the same `tabSelection` binding.

3. **Map `BRUTab` ↔ `RootView.Tab`.** Both enums have the same 5 cases
   (today / routines / library / progress / settings) in the same order,
   so the mapping is direct. Add small helpers `RootView.Tab.bru` and
   `BRUTab.rootTab` for the conversion.

4. **Preserve re-tap pop-to-root.** The existing `tabSelection`
   `Binding<Tab>` in `RootView.swift:137` already detects same-value
   sets and clears the matching `NavigationPath`. BRUTabBar's
   `onSelect` closure should write through this same binding, not
   `selectedTab` directly, so the re-tap behavior keeps working.

5. **Keep system `.tabItem` labels.** The SF-Symbol `Label("…")`
   modifiers on each tab are now invisible (chrome hidden) but they
   stay in place — they are what `TabView(selection:)` uses internally
   to identify tabs. Removing them is out of scope.

## Files modified

- `fitbod/App/RootView.swift` — wire BRUTabBar via safeAreaInset and
  hide default chrome.

## Out of scope

- Reskinning any tab body (Today, Routines, Library, Progress, Settings).
- Removing the `Label(…, systemImage:)` calls on each tab.
- Changing any navigation behavior beyond what's needed to drive
  selection from `BRUTabBar.onSelect`.

## Verification

- `xcodebuild` clean compile.
- Simulator launch: BRU bar renders at bottom, default chrome hidden,
  all 5 tabs switch correctly, active tab shows bruInk fill / bruPaper
  text, screens behind each tab still load.
