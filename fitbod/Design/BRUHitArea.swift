// BRUHitArea.swift
// fitbod
//
// Touch-target helper. BRU text links ("+ ADD SESSION", "‹ BACK") are drawn
// small on purpose, but they must stay comfortable to hit mid-workout.
// `bruHitArea()` grows the tappable region around a view without moving
// anything in the layout: it pads, claims the padded rectangle as the hit
// shape, then removes the padding from the layout with a negative pad.

import SwiftUI

public extension View {
    /// Extends this view's hit-test area by `amount` points on every edge
    /// without changing its layout footprint.
    ///
    /// Use on compact text buttons inside `.plain` button styles. Full-width
    /// rows should instead use `.contentShape(Rectangle())` on the row frame.
    func bruHitArea(_ amount: CGFloat = 12) -> some View {
        padding(amount)
            .contentShape(Rectangle())
            .padding(-amount)
    }
}
