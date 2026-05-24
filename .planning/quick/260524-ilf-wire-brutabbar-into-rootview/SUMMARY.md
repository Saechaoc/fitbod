---
quick_id: 260524-ilf
slug: wire-brutabbar-into-rootview
date: 2026-05-24
status: complete
---

# Quick Task 260524-ilf — Summary

## What changed

Replaced the SwiftUI default `TabView` chrome in `RootView` with the
existing `BRUTabBar` component. First incremental step of the BRU
visual rewrite restart — scope was intentionally limited to the bottom
nav container.

`fitbod/App/RootView.swift`:
- Removed `TabView(selection:)` block. Each tab body is now selected
  by a `switch selectedTab` inside a `VStack`, with `BRUTabBar` mounted
  below as the bottom row.
- The `Group { switch … }` body uses `.frame(maxWidth: .infinity,
  maxHeight: .infinity)` so it fills above the bar.
- `BRUTabBar` is constrained with `.fixedSize(horizontal: false,
  vertical: true)` because its cells use `minHeight: 56` (no max);
  without this, `VStack` lets the bar expand and consume ~40% of the
  screen.
- Added private `RootView.Tab` ↔ `BRUTab` conversion helpers
  (`Tab.bru`, `BRUTab.rootTab`) so the chrome component stays
  independent of `RootView`.
- The existing `tabSelection: Binding<Tab>` re-tap pop-to-root logic
  is preserved — `BRUTabBar.onSelect` writes through it.

## Why not `TabView` + `.toolbar(.hidden, for: .tabBar)`

Tried both `.toolbarBackground(.hidden, for: .tabBar)` (hides only the
blur, not the chrome) and `.toolbar(.hidden, for: .tabBar)` (only
takes effect from inside a `NavigationStack` child). On a `TabView`
itself, neither suppressed the system chrome — verified by screenshot.
Dropping `TabView` and doing manual `switch`-based tab selection is
the reliable pattern for a custom bottom nav.

## Why not `.safeAreaInset(edge: .bottom)`

Tried it; the inner tab bodies (e.g. `ExerciseLibraryView` with its
own `NavigationStack` + `.searchable` + `List`) interfered with the
inset, causing the bar to render mid-screen rather than pinned to the
bottom. A direct `VStack(spacing: 0) { content; bar }` placed the bar
exactly where intended on every tab.

## Verification

- `xcodebuild build` — **BUILD SUCCEEDED** (1 Sendable-closure warning
  on the new code, matching ~15 pre-existing identical warnings in
  the codebase; runtime safe — closure only fires on main from
  SwiftUI button taps).
- Simulator launch on iPhone 17 Pro — BRU bar renders at screen
  bottom, 56pt cell height, LIBRARY active in `bruInk` fill with
  `bruPaper` text, 1pt hair separators between cells, 2pt top rule.
  No system tab bar visible.
- Screenshot evidence at `/tmp/fitbod-tabbar-v6.png`.

## Out of scope (next steps)

- Reskinning any tab body (Today, Routines, Library, Progress,
  Settings) — these still use Apple HIG defaults.
- Resolving the `tabSelection` `@Sendable` warning (consistent with
  ~15 other warning sites; defer for batch fix).
- Replacing `+` SF Symbol in `ExerciseLibraryView` toolbar (visible
  in screenshot) — that's the Library tab's chrome, not the global
  tab bar.

## Files changed

- `fitbod/App/RootView.swift` (+57 / −48)

## Commits

- TBD (one atomic commit on completion).
