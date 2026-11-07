// BlockNavigation.swift
// fitbod
//
// Block navigation shared by the Today and Program stacks: what opens the
// block builder, and the block overview and routine screens both stacks
// push. Each tab keeps its own presentation of the builder (Today a
// sheet, Program a full-screen cover).

import SwiftUI
import SwiftData

/// What opens `BlockBuilderView`: a new block, from scratch or a preset;
/// a template; or a saved block to edit.
enum BlockBuilderRoute: Identifiable {
    case newBlock(NewBlockPreset?)
    case template(BlockTemplate)
    case edit(Block)

    var id: String {
        switch self {
        case .newBlock(let preset):
            return preset.map { "new-block-preset-\($0.id)" } ?? "new-block-scratch"
        case .template(let template):
            return "template-\(template.name)"
        case .edit(let block):
            return "edit-\(block.id.uuidString)"
        }
    }

    /// The builder this route opens; `origin` names the tab its back
    /// button returns to.
    @MainActor
    func builder(origin: BlockBuilderView.Origin) -> BlockBuilderView {
        switch self {
        case .newBlock(let preset):
            BlockBuilderView(draft: BlockDraft.newBlock(), initialPreset: preset, origin: origin)
        case .template(let template):
            BlockBuilderView(draft: BlockDraft(template: template), origin: origin)
        case .edit(let block):
            BlockBuilderView(draft: BlockDraft(block: block), editing: block, origin: origin)
        }
    }
}

extension View {
    /// Registers the `BlockOverviewRoute` and `SplitDetailRoute`
    /// destinations on the enclosing NavigationStack. EDIT on the block
    /// overview calls `onEdit`.
    func blockDestinations(onEdit: @escaping (Block) -> Void) -> some View {
        navigationDestination(for: BlockOverviewRoute.self) { route in
            switch route {
            case .summary(let blockID):
                BlockOverviewDestination(blockID: blockID, onEdit: onEdit)
            }
        }
        .navigationDestination(for: SplitDetailRoute.self) { route in
            switch route {
            case .detail(let splitID):
                SplitDetailDestination(splitID: splitID)
            }
        }
    }
}

/// Looks the block up by id when the overview is pushed. Once DELETE BLOCK
/// has deleted it, leaves for the screen it came from without reading it.
/// The query also drops a block deleted on the other tab, so that tab's
/// overview never draws it either.
private struct BlockOverviewDestination: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Block]
    let onEdit: (Block) -> Void
    /// Set by DELETE BLOCK, before anything reads the deleted block.
    @State private var deleted = false

    init(blockID: UUID, onEdit: @escaping (Block) -> Void) {
        _matches = Query(filter: #Predicate<Block> { $0.id == blockID })
        self.onEdit = onEdit
    }

    var body: some View {
        if deleted {
            Color.bruPaper
                .ignoresSafeArea()
                .navigationBarHidden(true)
                .onAppear { dismiss() }
        } else if let block = matches.first {
            BlockOverviewScreen(block: block, onEdit: { onEdit(block) }, onDeleted: { deleted = true })
        } else {
            Text("Block not found")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
    }
}

/// Looks the routine up by id when its detail is pushed.
private struct SplitDetailDestination: View {
    @Environment(\.modelContext) private var ctx
    let splitID: UUID

    var body: some View {
        let id = splitID
        if let split = (try? ctx.fetch(FetchDescriptor<Split>(predicate: #Predicate { $0.id == id })))?.first {
            SplitDetailView(split: split)
        } else {
            Text("Routine not found")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
    }
}
