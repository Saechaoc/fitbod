//
//  SeriesToggleChipRow.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — 4-segment inverted-active HStack.
//  Supersedes the Phase 6 baseline which used two ProgressFilterChips in an HStack.
//
//  BRU visual spec (06-UI-SPEC §Design Pivot key replacement 3 + bru-screens/progress-chart.jsx):
//    HStack(spacing: 0) inside a 1pt bruInk outer border + 2pt bruInk bottom rule.
//    Each cell: 8pt vertical padding, 1pt bruInk trailing divider (except last).
//    Selected: background Color.bruInk + foreground Color.bruPaper.
//    Unselected: background Color.clear + foreground Color.bruInk.
//    Labels: BRUFont.labelSmall UPPERCASE, 1.2 tracking.
//
//  4-cell layout (bru-screens/progress-chart.jsx):
//    [e1RM] [TOP SET] [VOLUME] [AVG RPE]
//
//  Current functional contract:
//    This component controls the top-set vs all-set-avg toggle via showTopSet / showAllAvg.
//    The "e1RM" and "VOLUME" cells are rendered (visually complete BRU chrome) but are
//    wired as pass-through no-ops — they do not yet control series data.
//    TODO: wire e1RM and VOLUME cells to chart series in a later iteration.
//
//  BRU contract: NO Capsule / NO RoundedRectangle / NO accentColor /
//  NO Image(systemName:) / NO .buttonStyle(.bordered) / NO .opacity(0.15) /
//  NO .font(.body|.headline|.caption)
//

import SwiftUI

public struct SeriesToggleChipRow: View {
    @Binding public var showTopSet: Bool
    @Binding public var showAllAvg: Bool

    public init(showTopSet: Binding<Bool>, showAllAvg: Binding<Bool>) {
        self._showTopSet = showTopSet
        self._showAllAvg = showAllAvg
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            // Cell 0 — e1RM (TODO: wire to e1RM series in future iteration)
            cell(label: "e1RM", isSelected: false, hasDivider: true) {
                // no-op until e1RM series is wired
            }

            // Cell 1 — TOP SET (active: controls showTopSet)
            cell(label: "TOP SET", isSelected: showTopSet, hasDivider: true) {
                showTopSet.toggle()
            }

            // Cell 2 — VOLUME (TODO: wire to volume series in future iteration)
            cell(label: "VOLUME", isSelected: false, hasDivider: true) {
                // no-op until volume series is wired
            }

            // Cell 3 — AVG RPE (active: controls showAllAvg)
            cell(label: "AVG RPE", isSelected: showAllAvg, hasDivider: false) {
                showAllAvg.toggle()
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
        )
        .background(Color.bruBg)
    }

    // MARK: - Cell builder

    @ViewBuilder
    private func cell(
        label: String,
        isSelected: Bool,
        hasDivider: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.bruInk : Color.clear)
                .overlay(alignment: .trailing) {
                    if hasDivider {
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(width: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Both off") {
    @Previewable @State var topSet = false
    @Previewable @State var allAvg = false
    SeriesToggleChipRow(showTopSet: $topSet, showAllAvg: $allAvg)
        .background(Color.bruBg)
}

#Preview("Top set active") {
    @Previewable @State var topSet = true
    @Previewable @State var allAvg = false
    SeriesToggleChipRow(showTopSet: $topSet, showAllAvg: $allAvg)
        .background(Color.bruBg)
}

#Preview("Both active") {
    @Previewable @State var topSet = true
    @Previewable @State var allAvg = true
    SeriesToggleChipRow(showTopSet: $topSet, showAllAvg: $allAvg)
        .background(Color.bruBg)
}
#endif
