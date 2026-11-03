// BlockSessionChoiceSheet.swift
// fitbod
//
// Today's "Choose a session" while a block runs (design map:
// today-session-choice): the block's sessions in routine order with the one
// Today schedules marked NEXT, START ▸ on each, and an empty workout.
// Starting a session counts as that day of the block, so a rotation carries
// on from it. There is no skip (docs/ROADMAP.md "Decided").
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

struct BlockSessionChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let block: Block
    /// The slot Today schedules or shows as up next, marked NEXT.
    let markedSlotID: UUID?
    let onStart: (SplitSessionSlot) -> Void
    let onStartEmpty: () -> Void

    private var slots: [SplitSessionSlot] {
        (block.split?.slots ?? [])
            .filter { $0.sessionTemplate != nil }
            .sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(left: HeaderAction("Close") { dismiss() }, center: "Sessions")
            ScrollView {
                VStack(spacing: 0) {
                    Text(note)
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    BRUDivider(.ink)
                    ForEach(slots, id: \.id) { slot in
                        if let template = slot.sessionTemplate {
                            row(slot: slot, template: template)
                            BRUDivider(.hair)
                        }
                    }
                    emptyRow
                    BRUDivider(.hair)
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
    }

    private var note: String {
        block.schedulingMode == .rotation
            ? "The session you start counts as the block's next day, and the rotation carries on from it."
            : "The session you start counts in this block. Your weekly schedule stays as planned."
    }

    private func row(slot: SplitSessionSlot, template: SessionTemplate) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(template.name)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if slot.id == markedSlotID {
                        Text("Next")
                            .font(BRUFont.labelMicro)
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruSignalText)
                    }
                }
                Text(SessionTemplateSummary(template: template).line)
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            BRUButton("Start ▸", kind: .signal, size: .md) { onStart(slot) }
                .frame(width: 104)
                .disabled((template.exercises ?? []).isEmpty)
                .accessibilityLabel("Start \(template.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Empty workout")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruInk)
                Text("Add exercises as you go")
                    .font(BRUFont.labelSmall)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            BRUButton("Start ▸", kind: .ghost, size: .md, action: onStartEmpty)
                .frame(width: 104)
                .accessibilityLabel("Start an empty workout")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
