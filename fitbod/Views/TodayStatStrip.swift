// TodayStatStrip.swift
// fitbod — Phase 2.1 Plan 04
//
// 3-cell BRU stat strip for the Today tab.
// Reference: bru-screens/today.jsx lines 10-20
//
// Layout: 3 BRUReadout cells in equal thirds with 1pt bruInk vertical
// dividers between them, and a 2pt bruInk bottom rule via BRUDivider(.ink).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI

// MARK: - TrendDirection

/// Direction used by slot 3 of TodayStatStrip to set value + color.
public enum TrendDirection {
    /// Upward trend — renders "↑" in bruSignal.
    case up
    /// Downward trend — renders "↓" in bruInk.
    case down
    /// No clear trend — renders the current phase's short label in bruInk,
    /// or "—" when the block has no current phase.
    case flat
}

// MARK: - TodayStatStrip

/// 3-cell BRU stat strip — Day streak / Sessions / block week or this week.
///
/// Layout:
/// ```
/// ┌───────────────┬───────────────┬───────────────┐
/// │  Day streak   │  Sessions   › │    W3 / 5     │
/// │      14       │      42       │       ↑       │
/// └───────────────┴───────────────┴───────────────┘
/// ══════════════════════════════════════════════════  2pt bruInk
/// ```
///
/// Slot 2 opens workout history when `onOpenHistory` is set; the "›" marks
/// it as tappable. Slot 3 shows the block week and the week-over-week trend
/// while a block is active, and "This week" (finished sessions this week)
/// otherwise, since a "W1 / 1" placeholder would mean nothing. A flat trend
/// shows the current phase's short label, such as "ACCUM", instead of a
/// dash (tradeoffs.md "Today's third stat"). Past the block's last planned
/// week, "PLAN COMPLETE" takes the week's place and no phase shows
/// (tradeoffs.md "A block past its plan").
///
/// Vertical 1pt bruInk dividers between cells; 2pt bruInk bottom rule.
/// The cells stack, with horizontal dividers, at accessibility sizes and
/// whenever a cell does not fit its third on one line, as "SESSIONS" does
/// at xxLarge on the 390pt phone, so no label breaks inside a word.
/// Reference: bru-screens/today.jsx lines 10-20.
public struct TodayStatStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Properties

    let streak: Int
    let totalSessions: Int
    let weekIndex: Int     // 1-based current week, e.g. 3
    let totalWeeks: Int    // total block weeks, e.g. 5
    let trend: TrendDirection
    /// The active block's current phase, shown when the trend is flat. Nil
    /// without one, as past the block's plan.
    let phase: BlockPhaseKind?
    /// True once the active block is past its last planned week.
    let isPlanComplete: Bool
    /// False when no block is active: slot 3 shows `sessionsThisWeek`.
    let hasActiveBlock: Bool
    /// Finished sessions in the current week.
    let sessionsThisWeek: Int
    /// Opens workout history from the Sessions cell. Nil keeps it static.
    let onOpenHistory: (() -> Void)?

    public init(
        streak: Int,
        totalSessions: Int,
        weekIndex: Int,
        totalWeeks: Int,
        trend: TrendDirection,
        phase: BlockPhaseKind? = nil,
        isPlanComplete: Bool = false,
        hasActiveBlock: Bool = true,
        sessionsThisWeek: Int = 0,
        onOpenHistory: (() -> Void)? = nil
    ) {
        self.streak = streak
        self.totalSessions = totalSessions
        self.weekIndex = weekIndex
        self.totalWeeks = totalWeeks
        self.trend = trend
        self.phase = phase
        self.isPlanComplete = isPlanComplete
        self.hasActiveBlock = hasActiveBlock
        self.sessionsThisWeek = sessionsThisWeek
        self.onOpenHistory = onOpenHistory
    }

    // MARK: - Computed

    private var weekLabel: String { "W\(weekIndex) / \(totalWeeks)" }

    private var trendValue: String {
        switch trend {
        case .up:   return "↑"
        case .down: return "↓"
        case .flat: return phase?.shortLabel ?? "—"
        }
    }

    private var trendSpoken: String {
        switch trend {
        case .up:   return "More sessions than last week"
        case .down: return "Fewer sessions than last week"
        case .flat: return phase?.rawValue.capitalized ?? "Same as last week"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .up:   return .bruSignal
        case .down, .flat: return .bruInk
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            StatStripLayout(stacks: dynamicTypeSize.isAccessibilitySize) {
                // Slot 1 — Day streak
                cell {
                    BRUReadout(
                        label: "Day streak",
                        value: "\(streak)",
                        accessibilityValue: BRUCountLabel.text(streak, "day")
                    )
                }

                divider

                // Slot 2 — Sessions, opens history
                if let onOpenHistory {
                    Button(action: onOpenHistory) {
                        cell {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                BRUReadout(label: "Sessions", value: "\(totalSessions)")
                                Spacer(minLength: 4)
                                // Same font as the label it sits beside: a
                                // taller glyph would push this readout below
                                // its neighbours.
                                Text("›")
                                    .font(BRUFont.labelSmall)
                                    .foregroundStyle(Color.bruMuted)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sessions")
                    .accessibilityValue("\(totalSessions)")
                    .accessibilityHint("Opens workout history")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("today.sessions")
                } else {
                    cell {
                        BRUReadout(label: "Sessions", value: "\(totalSessions)")
                    }
                }

                divider

                // Slot 3 — W{N} / {M} + trend, or this week's count
                cell {
                    if hasActiveBlock {
                        BRUReadout(
                            label: isPlanComplete ? PlanWeek.completeLabel : weekLabel,
                            value: trendValue,
                            valueColor: trendColor,
                            accessibilityLabel: isPlanComplete
                                ? "Block plan complete"
                                : "Block week \(weekIndex) of \(totalWeeks)",
                            accessibilityValue: trendSpoken
                        )
                    } else {
                        BRUReadout(
                            label: "This week",
                            value: "\(sessionsThisWeek)",
                            accessibilityLabel: "Sessions this week"
                        )
                    }
                }
                // PLAN COMPLETE may wrap between its two words in its third.
                .layoutValue(key: WrapsInItsThird.self, value: hasActiveBlock && isPlanComplete)
            }
            .fixedSize(horizontal: false, vertical: true)

            // 2pt bruInk bottom rule — section boundary
            BRUDivider(.ink)
        }
        .background(Color.bruPaper)
    }

    private func cell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    /// A 1pt rule between two cells; the layout makes it vertical between
    /// thirds and horizontal between stacked cells.
    private var divider: some View {
        Rectangle()
            .fill(Color.bruInk)
            .layoutValue(key: IsStatDivider.self, value: true)
    }
}

// MARK: - StatStripLayout

/// Marks a 1pt rule between two cells.
private struct IsStatDivider: LayoutValueKey {
    static let defaultValue = false
}

/// Marks a cell whose label may wrap between its words inside its third.
private struct WrapsInItsThird: LayoutValueKey {
    static let defaultValue = false
}

/// The strip's cells side by side in equal thirds, with a 1pt rule between
/// each, while every cell fits its third: its content on one line, unless
/// it is marked `WrapsInItsThird`. Otherwise, and always when `stacks` is
/// set, the cells stack full width with a 1pt rule between each.
private struct StatStripLayout: Layout {
    let stacks: Bool

    private static let rule: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealRowWidth(subviews)
        let frames = frames(in: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(in: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    /// Equal thirds, each as wide as the widest cell's one-line content.
    private func idealRowWidth(_ subviews: Subviews) -> CGFloat {
        let cells = subviews.filter { !$0[IsStatDivider.self] }
        let widest = cells.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return widest * CGFloat(cells.count) + Self.rule * CGFloat(subviews.count - cells.count)
    }

    /// Each subview's frame, from the strip's top left.
    private func frames(in width: CGFloat, subviews: Subviews) -> [CGRect] {
        let rules = subviews.count { $0[IsStatDivider.self] }
        let cells = max(subviews.count - rules, 1)
        let third = max(0, (width - Self.rule * CGFloat(rules)) / CGFloat(cells))
        let fitsInThirds = !stacks && subviews.allSatisfy { subview in
            subview[IsStatDivider.self] || subview[WrapsInItsThird.self]
                || subview.sizeThatFits(.unspecified).width <= third
        }

        var frames: [CGRect] = []
        if fitsInThirds {
            let height = subviews.filter { !$0[IsStatDivider.self] }
                .map { $0.sizeThatFits(ProposedViewSize(width: third, height: nil)).height }
                .max() ?? 0
            var x: CGFloat = 0
            for subview in subviews {
                let cellWidth = subview[IsStatDivider.self] ? Self.rule : third
                frames.append(CGRect(x: x, y: 0, width: cellWidth, height: height))
                x += cellWidth
            }
        } else {
            var y: CGFloat = 0
            for subview in subviews {
                let height = subview[IsStatDivider.self]
                    ? Self.rule
                    : subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
                frames.append(CGRect(x: 0, y: y, width: width, height: height))
                y += height
            }
        }
        return frames
    }
}

// MARK: - Preview

#if DEBUG
#Preview("TodayStatStrip") {
    VStack(spacing: 0) {
        TodayStatStrip(streak: 14, totalSessions: 42, weekIndex: 3, totalWeeks: 5, trend: .up)
        TodayStatStrip(streak: 0, totalSessions: 7, weekIndex: 1, totalWeeks: 4, trend: .flat,
                       hasActiveBlock: false, sessionsThisWeek: 2, onOpenHistory: {})
        TodayStatStrip(streak: 3, totalSessions: 21, weekIndex: 5, totalWeeks: 5, trend: .down)
        TodayStatStrip(streak: 1, totalSessions: 9, weekIndex: 1, totalWeeks: 4, trend: .flat,
                       phase: .accumulation)
        TodayStatStrip(streak: 1, totalSessions: 9, weekIndex: 1, totalWeeks: 4, trend: .flat,
                       isPlanComplete: true, onOpenHistory: {})
    }
    .background(Color.bruPaper)
}
#endif
