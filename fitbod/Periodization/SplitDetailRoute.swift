//
//  SplitDetailRoute.swift
//  fitbod
//
//  Phase 09-01 — typed navigation route for SplitDetailView.
//  Uses UUID identity (not a direct @Model reference) per Swift 6 Sendable
//  safety — parallel to BlockOverviewRoute in BlockOverviewScreen.swift.
//

import Foundation

// MARK: - SplitDetailRoute

/// Typed route for pushing SplitDetailView onto a NavigationPath.
/// Uses UUID identity per Swift 6 Sendable safety (Split @Model is not
/// Sendable across actor boundaries).
public enum SplitDetailRoute: Hashable, Sendable {
    case detail(splitID: UUID)
}
