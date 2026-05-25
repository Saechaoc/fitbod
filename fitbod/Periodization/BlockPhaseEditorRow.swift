//
//  BlockPhaseEditorRow.swift
//  fitbod
//
//  Inline editor for a single BlockPhaseDraft.
//  Phase 04.1 (BRU re-skin + D-15 a11y label) — see 04.1-PATTERNS.md File #4
//

import SwiftUI

public struct BlockPhaseEditorRow: View {
    @Bindable public var draft: BlockPhaseDraft
    public let displayIndex: Int

    public init(draft: BlockPhaseDraft, displayIndex: Int) {
        self.draft = draft
        self.displayIndex = displayIndex
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // NOW-row signal stripe: 4pt-wide bruSignal left-edge stripe when intensification
            if draft.kind == .intensification {
                Rectangle()
                    .fill(Color.bruSignal)
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Leading ordinal — per 04-UI-SPEC line 93
                    Text(String(format: "%02d", displayIndex))
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .frame(width: 28)

                    kindMenu
                    Spacer()

                    // Typographic drag glyph — replaces Image(systemName: "line.3.horizontal")
                    Text("⋮⋮")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Reorder phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
                }

                // 3-column data grid — replaces 3 Stepper rows
                Grid(horizontalSpacing: 4) {
                    GridRow {
                        weeksCell
                        volumeCell
                        intensityCell
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(BlockPhaseColors.rowTint(for: draft.kind))
        .accessibilityLabel("Phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
    }

    // MARK: - Data grid cells

    @ViewBuilder
    private var weeksCell: some View {
        VStack(spacing: 4) {
            Text("WEEKS")
                .font(BRUFont.labelMicro)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
            Text("\(draft.weeks)")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            HStack(spacing: 0) {
                Button {
                    if draft.weeks > 1 { draft.weeks -= 1 }
                } label: {
                    Text("−")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                Button {
                    if draft.weeks < 12 { draft.weeks += 1 }
                } label: {
                    Text("+")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.bruInk, lineWidth: 1))
    }

    @ViewBuilder
    private var volumeCell: some View {
        VStack(spacing: 4) {
            Text("VOL")
                .font(BRUFont.labelMicro)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
            Text("×\(formatMultiplier(draft.volumeMultiplier))")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            HStack(spacing: 0) {
                Button {
                    let newValue = (draft.volumeMultiplier - 0.05).rounded(toPlaces: 2)
                    if newValue >= 0.3 { draft.volumeMultiplier = newValue }
                } label: {
                    Text("−")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                Button {
                    let newValue = (draft.volumeMultiplier + 0.05).rounded(toPlaces: 2)
                    if newValue <= 1.5 { draft.volumeMultiplier = newValue }
                } label: {
                    Text("+")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.bruInk, lineWidth: 1))
    }

    @ViewBuilder
    private var intensityCell: some View {
        VStack(spacing: 4) {
            Text("INT")
                .font(BRUFont.labelMicro)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.bruMuted)
            Text("×\(formatMultiplier(draft.intensityMultiplier))")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruInk)
            HStack(spacing: 0) {
                Button {
                    let newValue = (draft.intensityMultiplier - 0.01).rounded(toPlaces: 2)
                    if newValue >= 0.3 { draft.intensityMultiplier = newValue }
                } label: {
                    Text("−")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                Button {
                    let newValue = (draft.intensityMultiplier + 0.01).rounded(toPlaces: 2)
                    if newValue <= 1.1 { draft.intensityMultiplier = newValue }
                } label: {
                    Text("+")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().stroke(Color.bruInk, lineWidth: 1))
    }

    // MARK: - Kind menu

    private var kindMenu: some View {
        Menu {
            ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                Button(BlockPhaseColors.phaseLabel(kind)) {
                    draft.kind = kind
                }
            }
        } label: {
            BRUChip(
                BlockPhaseColors.phaseLabel(draft.kind).uppercased(),
                color: chipColor(for: draft.kind),
                fill: shouldFillChip(for: draft.kind)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Chip color helpers (same logic as MesocycleWeekPage)

    private func chipColor(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .intensification, .deload:
            return Color.bruSignal
        default:
            return Color.bruInk
        }
    }

    private func shouldFillChip(for kind: BlockPhaseKind) -> Bool {
        kind == .intensification
    }

    // MARK: - Helpers (preserved verbatim)

    private func formatMultiplier(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}

// MARK: - Double rounding helper

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
