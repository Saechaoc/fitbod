//
//  ChalkAppearance.swift
//  fitbod
//
//  UIKit appearance hooks for the system chrome SwiftUI does not expose
//  directly: navigation-bar title fonts (condensed heavy, Dynamic Type
//  scaled) and segmented-control selection colors. Backgrounds are left
//  to the system so iOS 26 bars keep their native material.
//
//  Called once from `fitbodApp.init()`.
//

import SwiftUI
import UIKit

@MainActor
public enum ChalkAppearance {
    public static func apply() {
        let ink = ChalkPalette.ink.uiColor

        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: UIFont.systemFont(ofSize: 34, weight: .heavy, width: .condensed)
        )
        let inlineTitle = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: UIFont.systemFont(ofSize: 18, weight: .heavy, width: .condensed)
        )

        let navBar = UINavigationBar.appearance()
        navBar.largeTitleTextAttributes = [.font: largeTitle, .foregroundColor: ink]
        navBar.titleTextAttributes = [.font: inlineTitle, .foregroundColor: ink]

        let segmentFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: UIFont.systemFont(ofSize: 15, weight: .heavy, width: .condensed)
        )
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = ink
        segmented.setTitleTextAttributes(
            [.foregroundColor: ChalkPalette.canvas.uiColor, .font: segmentFont],
            for: .selected
        )
        segmented.setTitleTextAttributes(
            [.foregroundColor: ink, .font: segmentFont],
            for: .normal
        )
    }
}
