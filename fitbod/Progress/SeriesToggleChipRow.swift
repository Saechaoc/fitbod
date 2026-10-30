//
//  SeriesToggleChipRow.swift
//  fitbod
//
//  Phase 6.1 BRU reskin — 4-segment inverted-active HStack.
//  Supersedes the Phase 6 baseline which used two ProgressFilterChips in an HStack.
//
//  BRU visual spec (06-UI-SPEC §Design Pivot key replacement 3 + bru-screens/progress-chart.jsx):
//    HStack(spacing: 0) inside a 1pt bruInk outer border + 2pt bruInk bottom rule.
//    Each cell: at least 44pt tall, 1pt bruInk trailing divider (except last).
//    Selected: background Color.bruInk + foreground Color.bruPaper.
//    Unselected: background Color.clear + foreground Color.bruInk.
//    The whole cell takes taps, selected or not.
//    Labels: BRUFont.labelSmall UPPERCASE, 1.2 tracking.
//    At accessibility text sizes the cells sit in two rows of two.
//
//  4-cell layout (bru-screens/progress-chart.jsx):
//    [e1RM] [TOP SET] [VOLUME] [AVG RPE]
//
//  Functional contract:
//    One cell is selected at a time, because e1RM, volume and RPE do not
//    share an axis. The selected cell is the chart's ProgressChartMetric:
//      e1RM     top-set e1RM and all-set average e1RM (PROG-03), the default
//      TOP SET  top-set e1RM alone
//      VOLUME   weight × reps of the logged work sets, per workout
//      AVG RPE  mean RPE of the logged work sets that have one, per workout
//
//  BRU contract: NO Capsule / NO RoundedRectangle / NO accentColor /
//  NO Image(systemName:) / NO .buttonStyle(.bordered) / NO .opacity(0.15) /
//  NO .font(.body|.headline|.caption)
//

import SwiftUI

/// What the progress chart plots, one chip at a time.
public enum ProgressChartMetric: String, CaseIterable, Sendable {
    case e1RM
    case topSet
    case volume
    case averageRPE

    /// The chip label, shown uppercase.
    public var label: String {
        switch self {
        case .e1RM:       return "e1RM"
        case .topSet:     return "TOP SET"
        case .volume:     return "VOLUME"
        case .averageRPE: return "AVG RPE"
        }
    }
}

public struct SeriesToggleChipRow: View {
    @Binding public var selection: ProgressChartMetric
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(selection: Binding<ProgressChartMetric>) {
        self._selection = selection
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    cells([.e1RM, .topSet])
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(height: 1)
                    cells([.volume, .averageRPE])
                }
            } else {
                cells(ProgressChartMetric.allCases)
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
        )
        .background(Color.bruBg)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func cells(_ metrics: [ProgressChartMetric]) -> some View {
        HStack(spacing: 0) {
            ForEach(metrics, id: \.self) { metric in
                cell(metric, hasDivider: metric != metrics.last)
            }
        }
    }

    // MARK: - Cell builder

    private func cell(_ metric: ProgressChartMetric, hasDivider: Bool) -> some View {
        let isSelected = metric == selection
        return Button {
            selection = metric
        } label: {
            Text(metric.label)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? Color.bruPaper : Color.bruInk)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget)
                .background(isSelected ? Color.bruInk : Color.clear)
                .overlay(alignment: .trailing) {
                    if hasDivider {
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(width: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#if DEBUG
#Preview("e1RM selected") {
    @Previewable @State var metric = ProgressChartMetric.e1RM
    SeriesToggleChipRow(selection: $metric)
        .background(Color.bruBg)
}

#Preview("AVG RPE selected") {
    @Previewable @State var metric = ProgressChartMetric.averageRPE
    SeriesToggleChipRow(selection: $metric)
        .background(Color.bruBg)
}

#Preview("Accessibility size") {
    @Previewable @State var metric = ProgressChartMetric.volume
    SeriesToggleChipRow(selection: $metric)
        .background(Color.bruBg)
        .dynamicTypeSize(.accessibility3)
}
#endif
