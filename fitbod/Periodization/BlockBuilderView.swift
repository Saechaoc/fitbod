//
//  BlockBuilderView.swift
//  fitbod
//
//  Single-screen periodization block builder.
//  Phase 04.1 (BRU re-skin — ScrollView+VStack body + Canvas TIMELINE +
//  BRUSectionHead + BRUButton CTA + BRUHeaderBar) — see 04.1-PATTERNS.md File #1
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

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRUHeaderBar.slots(
                    left: .action("CANCEL") {
                        if hasUnsavedChanges {
                            presentingDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    },
                    center: editing == nil ? "New block" : "Edit block",
                    right: .empty
                )

                ScrollView {
                    VStack(spacing: 0) {
                        headerBand
                        timelineBand
                        phasesSection
                        linkedRoutinesBand
                        if let saveError {
                            errorBand(saveError)
                        }
                        applyChangesButton
                        safeAreaFiller
                    }
                }
            }
            .background(Color.bruBg)
            .navigationBarHidden(true)
        }
        .confirmationDialog("Discard Changes?",
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

    // MARK: - Header Band

    @ViewBuilder
    private var headerBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            // BLOCK NAME label
            Text("BLOCK NAME")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)

            // Block name text field — BRUFont.displayLarge (32pt)
            TextField("e.g. Powerlifting Peak Q3", text: $draft.name)
                .font(BRUFont.displayLarge)
                .foregroundStyle(Color.bruInk)
                .padding(.top, 4)

            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Block name is required.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruSignal)
                    .padding(.top, 4)
            }

            // START DATE label + DatePicker
            Text("START DATE")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
                .padding(.top, 12)

            DatePicker(
                "",
                selection: $draft.startDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .font(BRUFont.bodyDefault)
            .padding(.top, 4)

            // Active toggle — BRUChip styled button
            HStack(spacing: 8) {
                Button {
                    draft.isActive.toggle()
                } label: {
                    BRUChip("Active", color: .bruSignal, fill: draft.isActive)
                }
                .buttonStyle(.plain)

                if let replacingName {
                    Text("Replaces: \(replacingName)")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.top, 8)

            // Footer copy
            Text("Only one block can be active at a time.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.bruPaper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Timeline Band

    @ViewBuilder
    private var timelineBand: some View {
        let totalWeeks = max(draft.phases.reduce(0) { $0 + $1.weeks }, 1)

        VStack(alignment: .leading, spacing: 0) {
            // Header row: TIMELINE left, NOW · WN right
            HStack {
                Text("TIMELINE")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Text("NOW · W\(currentWeekLabel)")
                    .font(BRUFont.labelSmall)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruSignal)
            }
            .padding(.bottom, 8)

            if draft.phases.isEmpty {
                // Placeholder when no phases added yet
                Rectangle()
                    .fill(Color.bruFaint)
                    .frame(height: 56)
                    .overlay(
                        Rectangle().stroke(Color.bruInk, lineWidth: 2)
                    )
            } else {
                // 56pt Canvas TIMELINE
                Canvas { ctx, size in
                    let total = CGFloat(draft.phases.reduce(0) { $0 + $1.weeks })
                    var x: CGFloat = 0
                    for phase in draft.phases {
                        let width = (CGFloat(phase.weeks) / total) * size.width
                        let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                        switch phase.kind {
                        case .accumulation:
                            ctx.fill(Path(rect), with: .color(Color.bruInk.opacity(0.85)))
                        case .intensification:
                            ctx.fill(Path(rect), with: .color(Color.bruSignal))
                        case .realization:
                            ctx.fill(Path(rect), with: .color(Color.bruInk.opacity(0.25)))
                        case .deload:
                            BlockPhaseColors.drawDeloadStripes(ctx: ctx, rect: rect)
                        }
                        x += width
                    }
                }
                .frame(height: 56)
                .overlay(
                    Rectangle().stroke(Color.bruInk, lineWidth: 2)
                )
            }

            // Week column labels below Canvas
            if totalWeeks > 0 {
                HStack(spacing: 0) {
                    ForEach(0..<totalWeeks, id: \.self) { weekIdx in
                        Text("W\(weekIdx + 1)")
                            .font(BRUFont.labelSmall)
                            .tracking(0.8)
                            .foregroundStyle(Color.bruMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bruPaper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.bruInk)
                .frame(height: 2)
        }
    }

    // MARK: - Phases Section

    @ViewBuilder
    private var phasesSection: some View {
        VStack(spacing: 0) {
            BRUSectionHead(
                "Phases",
                right: "+ ADD PHASE",
                rightAction: nil
            )
            // Use overlay to embed the Menu on the right side of BRUSectionHead
            .overlay(alignment: .trailing) {
                Menu {
                    ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                        Button(BlockPhaseColors.phaseLabel(kind)) {
                            addPhase(kind)
                        }
                    }
                } label: {
                    Text("+ ADD PHASE")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruSignal)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }

            if draft.phases.isEmpty {
                VStack(spacing: 4) {
                    Text("Add a phase to define your mesocycle.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                    Text("Add at least one phase.")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(Color.bruSignal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.bruPaper)
            } else {
                // Inner List for .onMove / .onDelete mechanics
                List {
                    ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                        BlockPhaseEditorRow(draft: phase, displayIndex: index + 1)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.bruPaper)
                    }
                    .onMove { source, destination in
                        draft.phases.move(fromOffsets: source, toOffset: destination)
                    }
                    .onDelete { offsets in
                        draft.phases.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(draft.phases.count) * 120)
                .environment(\.editMode, .constant(.active))

                // Footer: total weeks summary
                Text("Total: \(draft.totalWeeks) weeks across \(draft.phases.count) phases.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bruPaper)
            }
        }
    }

    // MARK: - Linked Routines Band

    @ViewBuilder
    private var linkedRoutinesBand: some View {
        let routines: [Routine] = editing?.routines ?? []

        VStack(spacing: 0) {
            BRUSectionHead("Linked routines · \(routines.count)")

            if routines.isEmpty {
                Text("No routines linked yet.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.bruPaper)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.bruInk)
                            .frame(height: 2)
                    }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(routines, id: \.id) { routine in
                            BRUChip(routine.name, textCase: nil)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.bruPaper)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.bruInk)
                        .frame(height: 2)
                }
            }
        }
    }

    // MARK: - Error Band

    @ViewBuilder
    private func errorBand(_ message: String) -> some View {
        Text(message)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .foregroundStyle(Color.bruSignal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.bruFaint)
    }

    // MARK: - Apply Changes Button

    @ViewBuilder
    private var applyChangesButton: some View {
        BRUButton("Apply changes ▸", kind: .primary, size: .lg) {
            save()
        }
        .disabled(!draft.isValid)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color.bruBg)
    }

    // MARK: - Safe Area Filler

    @ViewBuilder
    private var safeAreaFiller: some View {
        Rectangle()
            .fill(Color.bruBg)
            .frame(height: 24)
    }

    // MARK: - Current week label helper

    private var currentWeekLabel: Int {
        guard let editing else { return 1 }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: editing.startDate, to: .now).day ?? 0
        let weekIndex = max(0, daysSinceStart / 7)
        let totalWeeks = draft.phases.reduce(0) { $0 + $1.weeks }
        return min(weekIndex + 1, max(totalWeeks, 1))
    }

    // MARK: - Data layer (preserved verbatim from original)

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
