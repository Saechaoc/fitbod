//
//  BlockPickerMenu.swift
//  fitbod
//
//  Routine-builder header row for linking a routine to a periodization
//  block. The draft stores only a UUID until Save; RoutineDraft
//  materializes the SwiftData relationship transactionally.
//

import SwiftData
import SwiftUI

public struct BlockPickerMenu: View {
    @Binding public var blockID: UUID?

    @Query(sort: [SortDescriptor(\Block.startDate, order: .reverse)])
    private var blocks: [Block]

    @State private var pendingCreateBlock = false

    public init(blockID: Binding<UUID?>) {
        self._blockID = blockID
    }

    public var body: some View {
        Menu {
            Button("No Block") {
                blockID = nil
            }

            ForEach(sortedBlocks) { block in
                Button {
                    blockID = block.id
                } label: {
                    HStack {
                        if block.isActive {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                        }
                        Text(block.name)
                    }
                }
            }

            Divider()

            Button("+ Create New Block") {
                pendingCreateBlock = true
            }
            .foregroundStyle(Color.accentColor)
        } label: {
            HStack {
                Text("Block:")
                Spacer()
                Text(currentBlockLabel)
                    .foregroundStyle(blockID == nil ? Color.secondary : Color.accentColor)
            }
        }
        .sheet(isPresented: $pendingCreateBlock) {
            BlockBuilderView(draft: BlockDraft(template: BlockTemplates.blank))
        }
        .accessibilityLabel("Block: \(currentBlockLabel)")
        .accessibilityHint("Tap to assign this routine to a block.")
        .accessibilityValue(currentBlockLabel)
    }

    private var sortedBlocks: [Block] {
        BlockRow.sortedForDisplay(blocks)
    }

    private var currentBlockLabel: String {
        guard let blockID else { return "None" }
        return blocks.first(where: { $0.id == blockID })?.name ?? "None"
    }
}
