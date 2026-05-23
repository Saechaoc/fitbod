//
//  BlockPhaseEditorRow.swift
//  fitbod
//
//  Inline editor for a single BlockPhaseDraft.
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                kindMenu
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Reorder phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
            }

            Stepper(value: $draft.weeks, in: 1...12) {
                LabeledContent("Weeks") {
                    Text("\(draft.weeks) \(draft.weeks == 1 ? "week" : "weeks")")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $draft.volumeMultiplier, in: 0.3...1.5, step: 0.05) {
                LabeledContent("Volume ×") {
                    Text("×\(formatMultiplier(draft.volumeMultiplier))")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $draft.intensityMultiplier, in: 0.3...1.1, step: 0.01) {
                LabeledContent("Intensity ×") {
                    Text("×\(formatMultiplier(draft.intensityMultiplier))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityHint("Delete")
    }

    private var kindMenu: some View {
        Menu {
            ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                Button(BlockPhaseColors.phaseLabel(kind)) {
                    draft.kind = kind
                }
            }
        } label: {
            Text(BlockPhaseColors.phaseLabel(draft.kind))
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(BlockPhaseColors.color(for: draft.kind))
                .foregroundStyle(Color.white)
                .clipShape(Capsule())
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func formatMultiplier(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
