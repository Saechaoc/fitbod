//
//  InSessionPRBanner.swift
//  fitbod
//
//  Wave-4 plan 06-07 — view-root capsule banner driven by
//  `InSessionPRState.currentBanner` (CONTEXT D-15 + UI-SPEC § "In-
//  session PR banner"). Mounted via `.safeAreaInset(edge: .top)` on
//  `SessionLoggerView` per RESEARCH Pattern 3 — never inside scroll
//  content (anti-pattern: scroll-content mounting causes layout
//  shift when the banner appears/disappears).
//
//  ## Visual contract (UI-SPEC item 25)
//
//  - 44pt min-height capsule
//  - Background `Color.accentColor.opacity(0.15)`
//  - 1pt `Color.accentColor.opacity(0.3)` border via RoundedRectangle
//    overlay
//  - 22pt corner radius (matches capsule shape)
//  - Chips separated by Text(" · ") middot
//  - Optional `.caption` sub-line "{weight} kg × {reps}" below chips
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
//  - accessibilityHint: "Double-tap to dismiss"
//  - .accessibilityAddTraits(.isButton)
//
//  ## Motion
//
//  `@Environment(\.accessibilityReduceMotion)` gates the slide-down
//  transition — opacity-only when reduce-motion is on, slide+opacity
//  combined otherwise. 200ms cap per CONTEXT D-35.
//
//  [CITED: CONTEXT D-15 + UI-SPEC § In-session PR banner + RESEARCH
//   Pattern 3 + Anti-Patterns]
//

import SwiftUI

public struct InSessionPRBanner: View {
    @Bindable public var state: InSessionPRState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(state: InSessionPRState) {
        self._state = Bindable(wrappedValue: state)
    }

    public var body: some View {
        Group {
            if let content = state.currentBanner {
                capsule(content: content)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            } else {
                EmptyView()
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: state.currentBanner)
    }

    @ViewBuilder
    private func capsule(content: InSessionPRBannerContent) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(content.kinds.enumerated()), id: \.offset) { idx, kind in
                    if idx > 0 {
                        Text(" · ")
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(label(for: kind))
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                }
            }
            Text("\(formatWeight(content.weight)) kg × \(content.reps)")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.accentColor.opacity(0.15))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 16)
        .onTapGesture {
            state.dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(content: content))
        .accessibilityHint("Double-tap to dismiss")
        .accessibilityAddTraits(.isButton)
    }

    private func label(for kind: PRKind) -> String {
        switch kind {
        case .weight: return "Weight PR"
        case .reps:   return "Rep PR"
        case .volume: return "Volume PR"
        case .e1RM:   return "e1RM PR"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    private func accessibilityLabel(content: InSessionPRBannerContent) -> String {
        let joined = content.kinds.map { label(for: $0) }.joined(separator: ", ")
        return "\(content.kinds.count) personal records: \(joined)"
    }
}
