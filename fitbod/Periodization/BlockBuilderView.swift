//
//  BlockBuilderView.swift
//  fitbod
//
//  Single-screen periodization block builder.
//

import SwiftData
import SwiftUI

public struct BlockBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: BlockDraft

    public let editing: Block?

    @Query(filter: #Predicate<Block> { $0.isActive == true })
    private var activeBlocks: [Block]

    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot = ""
    @State private var saveError: String? = nil

    public init(draft: BlockDraft, editing: Block? = nil) {
        self.draft = draft
        self.editing = editing
    }

    public var body: some View {
        Form {
            Section {
                TextField("Block name", text: $draft.name, prompt: Text("e.g. Powerlifting Peak Q3"))
                if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Block name is required.")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }

                DatePicker("Start date", selection: $draft.startDate, displayedComponents: .date)

                Toggle("Active block", isOn: $draft.isActive)
                if let replacingName {
                    Text("Saving as active will replace your current active block: \(replacingName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Only one block can be active at a time. Activating this block deactivates any other.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if draft.phases.isEmpty {
                    Text("Add a phase to define your mesocycle.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                        BlockPhaseEditorRow(draft: phase, displayIndex: index + 1)
                    }
                    .onMove { source, destination in
                        draft.phases.move(fromOffsets: source, toOffset: destination)
                    }
                    .onDelete { offsets in
                        draft.phases.remove(atOffsets: offsets)
                    }
                }

                if draft.phases.isEmpty {
                    Text("Add at least one phase.")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            } header: {
                HStack {
                    Text("Phases")
                    Spacer()
                    Menu("+ Phase") {
                        ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                            Button(BlockPhaseColors.phaseLabel(kind)) {
                                addPhase(kind)
                            }
                        }
                    }
                    .foregroundStyle(Color.accentColor)
                }
            } footer: {
                Text("Total: \(draft.totalWeeks) weeks across \(draft.phases.count) phases.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(editing == nil ? "New Block" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        presentingDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    save()
                }
                .disabled(!draft.isValid)
                .foregroundStyle(Color.accentColor)
            }
        }
        .confirmationDialog(
            "Discard Changes?",
            isPresented: $presentingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {
                presentingDiscardConfirm = false
            }
        }
        .onAppear {
            initialSnapshot = snapshotHash()
        }
    }

    private var replacingName: String? {
        guard draft.isActive else { return nil }
        return activeBlocks.first { $0.id != draft.id }?.name
    }

    private var hasUnsavedChanges: Bool {
        snapshotHash() != initialSnapshot
    }

    private func snapshotHash() -> String {
        let phaseHash = draft.phases.map {
            "\($0.kind.rawValue)|\($0.weeks)|\($0.volumeMultiplier)|\($0.intensityMultiplier)"
        }
        .joined(separator: ",")
        return "\(draft.name)|\(draft.startDate.timeIntervalSince1970)|\(draft.isActive)|\(phaseHash)"
    }

    private func addPhase(_ kind: BlockPhaseKind) {
        let defaults = BlockPhaseDraft.defaultMultipliers(for: kind)
        let phase = BlockPhaseDraft(
            kind: kind,
            weeks: kind == .deload ? 1 : 4,
            volumeMultiplier: defaults.volume,
            intensityMultiplier: defaults.intensity
        )
        draft.phases.append(phase)
    }

    private func save() {
        do {
            try draft.save(into: ctx)
            dismiss()
        } catch {
            saveError = "Couldn't save block. Try again."
        }
    }
}
