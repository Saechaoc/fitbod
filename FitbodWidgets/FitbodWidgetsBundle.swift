//
//  FitbodWidgetsBundle.swift
//  FitbodWidgets
//
//  Widget Extension entry point. Apple's `@main`-on-`WidgetBundle` pattern
//  is the canonical shape for widget extensions that host one or more
//  widgets / Live Activities. Phase 2 ships exactly one widget:
//  `RestTimerLiveActivity` (the rest-timer Live Activity declaration
//  consumed by the lock screen and Dynamic Island).
//
//  Future widgets (home-screen workout summary, last-session glance, etc.)
//  would be added here as additional members of `body`. WidgetKit calls
//  `WidgetBundleBuilder.buildBlock(_:_:_:...)` under the hood — up to ~10
//  widgets per bundle is the standard ceiling.
//

import SwiftUI
import WidgetKit

@main
struct FitbodWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}
