//
//  InSessionPRBanner.swift
//  fitbod
//
//  Wave-4 plan 06-07 → Phase 06.1-06 BRU reskin
//
//  Full-bleed Color.bruSignal slab mounted via `.safeAreaInset(edge: .top)`
//  on `SessionLoggerView` per RESEARCH Pattern 3. Driven by
//  `InSessionPRState.currentBanner` (CONTEXT D-15).
//
//  ## Visual contract (UI-SPEC v2 § Design Pivot #10)
//
//  - Full-bleed Color.bruSignal background (no capsule, no corner radius)
//  - 44pt minHeight
//  - Layer 1: uppercase "PR" caption — BRUFont.labelSmall + tracking 1.5
//  - Layer 2: PR-kinds composite — BRUDisplay .medium, bruPaper
//             canonical order: weight → reps → volume → e1RM, middot-joined
//             e.g. "WEIGHT PR · VOLUME PR"
//  - Layer 3: set detail sub-line — BRUFont.labelSmall, bruPaper 0.8 opacity
//             e.g. "BENCH PRESS · 102.5 KG × 5"
//  - 16pt horizontal padding, 8pt vertical
//
//  ## Interaction
//
//  - Tap-to-dismiss → calls `state.dismiss()`
//  - 5s auto-dismiss (handled inside `observeSave`)
//  - Next-save-with-no-PRs clears banner (handled inside `observeSave`)
//
//  ## Accessibility (UI-SPEC item 621)
//
//  - accessibilityLabel: "{count} personal records: {labels joined}"
//  - accessibilityHint: "Tap to dismiss. Auto-dismisses in 5 seconds or on next set save."
//  - .accessibilityAddTraits(.isButton)
//  - .updatesFrequently trait preserved
//  - UIAccessibility.post(notification: .announcement) on appearance preserved
//
//  ## Motion
//
//  `@Environment(\.accessibilityReduceMotion)` gates the slide-down
//  transition — opacity-only when reduce-motion is on, slide+opacity
//  combined otherwise. 200ms cap per CONTEXT D-35.
//
//  [CITED: CONTEXT D-15 + UI-SPEC v2 § Design Pivot #10 + RESEARCH
//   Pattern 3 + Anti-Patterns]
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct InSessionPRBanner: View {
    @Bindable public var state: InSessionPRState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weightUnit) private var defaultUnit

    public init(state: InSessionPRState) {
        self._state = Bindable(wrappedValue: state)
    }

    public var body: some View {
        Group {
            if let content = state.currentBanner {
                slab(content: content)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        #if canImport(UIKit)
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: accessibilityLabel(content: content)
                        )
                        #endif
                    }
            } else {
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: state.currentBanner)
    }

    // MARK: - Slab layout

    @ViewBuilder
    private func slab(content: InSessionPRBannerContent) -> some View {
        VStack(spacing: 2) {
            // Layer 1: "PR" caption label
            // Black on orange: white on bruSignal measures 2.96:1 and fails.
            Text("PR")
                .font(BRUFont.labelSmall)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruOnSignal)

            // Layer 2: PR-kinds composite (BRUDisplay medium)
            BRUDisplay(prCompositeLabel(kinds: content.kinds), size: .medium, color: Color.bruOnSignal)

            // Layer 3: set-detail mono sub-line
            Text(setDetailMono(content: content))
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.bruOnSignal.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.bruSignal)
        .contentShape(Rectangle())
        .onTapGesture {
            state.dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(content: content))
        .accessibilityHint("Tap to dismiss. Auto-dismisses in 5 seconds or on next set save.")
        .accessibilityAddTraits([.isButton, .updatesFrequently])
    }

    // MARK: - Label helpers

    /// Formats PR kinds in canonical order, middot-joined, uppercase.
    /// e.g. [.weight, .volume] → "WEIGHT PR · VOLUME PR"
    private func prCompositeLabel(kinds: [PRKind]) -> String {
        kinds.map { kindLabel(for: $0) }.joined(separator: " · ")
    }

    /// Formats the set-detail sub-line per UI-SPEC verbatim:
    /// "BENCH PRESS · 102.5 KG × 5"
    private func setDetailMono(content: InSessionPRBannerContent) -> String {
        let unit = content.unitOverride ?? defaultUnit
        let set = "\(formatWeight(content.weight)) \(unit.rawValue) × \(content.reps)"
        return content.exerciseName.isEmpty ? set : "\(content.exerciseName) · \(set)"
    }

    private func kindLabel(for kind: PRKind) -> String {
        switch kind {
        case .weight: return "WEIGHT PR"
        case .reps:   return "REP PR"
        case .volume: return "VOLUME PR"
        case .e1RM:   return "E1RM PR"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    /// "Personal record, weight. Bench Press, 225 pounds, 5 reps."
    private func accessibilityLabel(content: InSessionPRBannerContent) -> String {
        let kinds = content.kinds.map(\.spokenName).joined(separator: ", ")
        let lead = content.kinds.count == 1
            ? "Personal record, \(kinds)."
            : "\(content.kinds.count) personal records: \(kinds)."
        let unit = content.unitOverride ?? defaultUnit
        let unitName = unit == .kg ? "kilograms" : "pounds"
        let set = "\(formatWeight(content.weight)) \(unitName), \(content.reps) reps."
        return content.exerciseName.isEmpty
            ? "\(lead) \(set)"
            : "\(lead) \(content.exerciseName), \(set)"
    }
}
