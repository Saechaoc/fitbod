//
//  BlockPhaseColors.swift
//  fitbod
//
//  Inline Phase 4 palette helpers. No asset catalog entries are added;
//  the locked UI-SPEC phase colors live here as inspectable Swift values.
//

import SwiftUI

public enum BlockPhaseColors {
    public static func color(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:
            return Color.accentColor
        case .intensification:
            return Color(red: 0.96, green: 0.62, blue: 0.04)
        case .realization:
            return Color(red: 0.92, green: 0.34, blue: 0.05)
        case .deload:
            return Color(red: 0.58, green: 0.64, blue: 0.72)
        }
    }

    public static func tint(for kind: BlockPhaseKind) -> Color {
        color(for: kind).opacity(0.15)
    }

    public static func phaseLabel(_ kind: BlockPhaseKind) -> String {
        kind.rawValue.capitalized
    }
}
