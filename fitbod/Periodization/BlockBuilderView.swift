//
//  BlockBuilderView.swift
//  fitbod
//
//  Full-screen New Block editor matching bru-screens/New-block/new-block.png.
//

import SwiftData
import SwiftUI

public struct BlockBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: BlockDraft

    public let editing: Block?

    private let initialPreset: NewBlockPreset?

    @State private var presentingDiscardConfirm = false
    @State private var presentingTemplateSheet = false
    @State private var presentingDurationSheet = false
    @State private var presentingDaysSheet = false
    @State private var initialSnapshot = ""
    @State private var saveError: String? = nil
    @State private var selectedPreset: NewBlockPreset = .blank
    @State private var didApplyInitialPreset = false
    @State private var pendingPresetToApply: NewBlockPreset? = nil
    @State private var presentingApplyPresetConfirm = false
    @State private var presentingAddPhaseTypePicker = false
    @State private var editMode: EditMode = .inactive
    @State private var pendingDelete: (phase: BlockPhaseDraft, index: Int)? = nil
    @State private var undoTask: Task<Void, Never>? = nil

    init(draft: BlockDraft, editing: Block? = nil, initialPreset: NewBlockPreset? = nil) {
        self.draft = draft
        self.editing = editing
        self.initialPreset = initialPreset
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    NewBlockTopBar(
                        title: editing == nil ? "NEW BLOCK" : "EDIT BLOCK",
                        onBack: cancel,
                        onSave: saveIfValid
                    )

                    // D7a/D7b: SwiftUI List — plain style with full-bleed rows preserving
                    // the brutalist look. PHASES header is a Section header so it pins
                    // while scrolling. NewBlockBottomActionBar stays outside as a ZStack
                    // overlay; bottom clearance is a trailing spacer row.
                    // D7b: edit mode is bound via .environment(\.editMode, $editMode) so
                    // the native List move handles appear when editMode == .active.
                    List {
                        // ── Upper bands ─────────────────────────────────────────────
                        // Block Name
                        NewBlockNameBand(draft: draft)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        // Block Settings
                        NewBlockMetricsBand(
                            draft: draft,
                            onEditWeeks: { presentingDurationSheet = true },
                            onEditDays: { presentingDaysSheet = true }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        // Timeline preview (bands paint their own paper background)
                        NewBlockTimelinePreview(phases: draft.phases)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        // D2: baseline legend row
                        Text("VOL Δ vs base · INT % of training max")
                            .font(NewBlockType.micro)
                            .tracking(0.8)
                            .foregroundStyle(NewBlockScreenTokens.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                            .padding(.top, NewBlockScreenTokens.tightGap)
                            .padding(.bottom, NewBlockScreenTokens.microGap)
                            .background(NewBlockScreenTokens.paper)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        // ── Phases Section ──────────────────────────────────────────
                        // The Section header pins automatically in a plain List.
                        Section {
                            ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                                NewBlockPhaseEditorRow(draft: phase, displayIndex: index + 1)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    // D7b: swipe-delete (NOT .onDelete — need index for undo)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            beginPendingDelete(phase)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                            // D7b: .onMove gated by editMode (toggle in pinned header)
                            .onMove { from, to in
                                draft.phases.move(fromOffsets: from, toOffset: to)
                            }
                        } header: {
                            NewBlockPhasesHeader(
                                phaseCount: draft.phases.count,
                                selectedPreset: selectedPreset,
                                isReordering: editMode == .active,
                                onToggleReorder: {
                                    editMode = editMode == .active ? .inactive : .active
                                },
                                onSelectPreset: { preset in
                                    if presetWouldReplacePhases(preset) {
                                        pendingPresetToApply = preset
                                        presentingApplyPresetConfirm = true
                                    } else {
                                        applyPreset(preset)
                                    }
                                }
                            )
                            .listRowInsets(EdgeInsets())
                        }

                        // ── Bottom rows ─────────────────────────────────────────────
                        // D6: full-width Add Phase row
                        NewBlockAddPhaseSlot(
                            onTap: { presentingAddPhaseTypePicker = true }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        if draft.isValid {
                            NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        if let saveError {
                            errorBand(saveError)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // Bottom clearance spacer: keeps the last row visible above the
                        // action bar. Uses safeAreaInset equivalent via a clear spacer row.
                        Color.clear
                            .frame(height: NewBlockScreenTokens.bottomActionHeight
                                + NewBlockScreenTokens.scrollBottomClearance)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(NewBlockScreenTokens.paper)
                    .scrollIndicators(.hidden)
                    // D7b: bind edit mode so native move handles appear in active mode
                    .environment(\.editMode, $editMode)
                }

                // D7b: transient undo toast — visible above the action bar while
                // pendingDelete is non-nil; auto-dismisses when the 4s Task clears it.
                if pendingDelete != nil {
                    NewBlockUndoToast(onUndo: undoDelete)
                        .padding(.bottom, NewBlockScreenTokens.bottomActionHeight
                            + NewBlockScreenTokens.tightGap)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                NewBlockBottomActionBar(
                    canCreate: draft.isValid,
                    isEditing: editing != nil,
                    onCancel: cancel,
                    onPrimary: saveIfValid
                )
            }
            .background(NewBlockScreenTokens.paper.ignoresSafeArea())
            .navigationBarHidden(true)
            .animation(.easeInOut(duration: 0.2), value: pendingDelete != nil)
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
        .sheet(isPresented: $presentingTemplateSheet) {
            NewBlockTemplateSheet(
                selected: selectedPreset,
                onSelect: { preset in
                    presentingTemplateSheet = false
                    if presetWouldReplacePhases(preset) {
                        pendingPresetToApply = preset
                        presentingApplyPresetConfirm = true
                    } else {
                        applyPreset(preset)
                    }
                }
            )
        }
        .sheet(isPresented: $presentingDurationSheet) {
            NewBlockDurationSheet(draft: draft)
        }
        .sheet(isPresented: $presentingDaysSheet) {
            NewBlockDaysSheet(draft: draft)
        }
        .sheet(isPresented: $presentingAddPhaseTypePicker) {
            NewBlockAddPhaseTypeSheet { kind in
                addPhase(of: kind)
                presentingAddPhaseTypePicker = false
            }
        }
        .confirmationDialog(
            "Apply Preset?",
            isPresented: $presentingApplyPresetConfirm,
            titleVisibility: .visible
        ) {
            Button("Apply", role: .destructive) {
                if let p = pendingPresetToApply {
                    applyPreset(p)
                }
                pendingPresetToApply = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPresetToApply = nil
            }
        } message: {
            Text("This will replace your current phases and settings.")
        }
        .onAppear {
            if initialPreset == nil {
                selectedPreset = NewBlockPreset.matching(name: draft.name)
            }
            if initialSnapshot.isEmpty {
                initialSnapshot = snapshotHash()
            }
        }
        .task {
            guard !didApplyInitialPreset else { return }
            didApplyInitialPreset = true
            if let preset = initialPreset, preset != .blank {
                applyPreset(preset)
            }
        }
    }

    private func cancel() {
        if hasUnsavedChanges {
            presentingDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func saveIfValid() {
        guard draft.isValid else { return }
        do {
            draft.isActive = false
            try draft.save(into: ctx)
            dismiss()
        } catch {
            saveError = "Couldn't save block. Try again."
        }
    }

    private func presentPresetPicker() {
        presentingTemplateSheet = true
    }

    private func presetWouldReplacePhases(_ preset: NewBlockPreset) -> Bool {
        preset == .hypertrophyMeso && !draft.phases.isEmpty
    }

    private func applyPreset(_ preset: NewBlockPreset) {
        draft.name = preset.displayName
        draft.daysPerWeek = 4
        selectedPreset = preset

        if preset == .hypertrophyMeso {
            draft.phases = BlockTemplates.hypertrophy.phases.map { phase in
                BlockPhaseDraft(
                    kind: phase.kind,
                    weeks: phase.weeks,
                    volumeMultiplier: phase.volumeMultiplier,
                    intensityMultiplier: phase.intensityMultiplier
                )
            }
        }
    }

    // D6: kind-parameterized append used by the add-phase type picker.
    private func addPhase(of kind: BlockPhaseKind) {
        let defaults = BlockPhaseDraft.defaultMultipliers(for: kind)
        draft.phases.append(
            BlockPhaseDraft(
                kind: kind,
                weeks: 1,
                volumeMultiplier: defaults.volume,
                intensityMultiplier: defaults.intensity
            )
        )
    }

    // Legacy convenience: still used by any remaining call site.
    private func addDefaultPhase() {
        addPhase(of: .accumulation)
    }

    // D7b: swipe-delete undo affordance.
    // beginPendingDelete captures {phase, index}, removes from draft.phases, cancels any
    // prior undoTask, and starts a 4s @MainActor Task that clears pendingDelete on timeout.
    // The whole view is @MainActor so the Task body touches view state directly.
    // Swift 6: state is built inside the Task and Task.isCancelled is checked after sleep.
    private func beginPendingDelete(_ phase: BlockPhaseDraft) {
        guard let index = draft.phases.firstIndex(where: { $0.draftID == phase.draftID }) else { return }
        pendingDelete = (phase: phase, index: index)
        draft.phases.remove(at: index)
        undoTask?.cancel()
        undoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            pendingDelete = nil
        }
    }

    // Cancels the undo timer and reinserts the phase at its original index.
    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        if let pd = pendingDelete {
            draft.phases.insert(pd.phase, at: min(pd.index, draft.phases.count))
            pendingDelete = nil
        }
    }

    private var hasUnsavedChanges: Bool {
        snapshotHash() != initialSnapshot
    }

    private func snapshotHash() -> String {
        let phaseHash = draft.phases.map {
            "\($0.kind.rawValue)|\($0.weeks)|\($0.volumeMultiplier)|\($0.intensityMultiplier)"
        }
        .joined(separator: ",")
        return "\(draft.name)|\(draft.startDate.timeIntervalSince1970)|\(draft.isActive)|\(draft.daysPerWeek)|\(phaseHash)"
    }

    private func errorBand(_ message: String) -> some View {
        Text(message)
            .font(NewBlockType.label)
            .tracking(NewBlockScreenTokens.labelTracking)
            .foregroundStyle(NewBlockScreenTokens.signal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, NewBlockScreenTokens.sidePadding)
            .padding(.vertical, 8)
            .background(NewBlockScreenTokens.faint)
    }
}

// MARK: - Tokens

fileprivate enum NewBlockScreenTokens {
    static let paper = Color(red: 240 / 255, green: 237 / 255, blue: 229 / 255)
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let muted = Color(red: 126 / 255, green: 123 / 255, blue: 114 / 255)
    static let hair = Color(red: 212 / 255, green: 209 / 255, blue: 202 / 255)
    static let faint = Color(red: 232 / 255, green: 229 / 255, blue: 221 / 255)
    static let signal = Color(red: 255 / 255, green: 77 / 255, blue: 46 / 255)

    static let sidePadding: CGFloat = 16
    static let rule: CGFloat = 1
    static let heavyRule: CGFloat = 3
    static let labelTracking: CGFloat = 2.2
    static let chipTracking: CGFloat = 2.1

    // Named vertical-rhythm scale (260528-cby). Use these in every band's
    // .padding(.top/.bottom/.vertical) and VStack/HStack spacing to tune the
    // whole screen from one place. Bare CGFloat literals in band internals
    // are an anti-pattern.
    static let microGap:   CGFloat = 4
    static let tightGap:   CGFloat = 6
    static let rowGap:     CGFloat = 8
    static let sectionGap: CGFloat = 10

    // CTA button tracking (bottom bar CANCEL + primary labels).
    static let ctaTracking: CGFloat = 2.8

    static let topBarRowHeight: CGFloat = 50
    static let nameBandHeight: CGFloat = 80
    static let metricsHeight: CGFloat = 92
    static let phasesHeaderHeight: CGFloat = 36
    static let previewHeight: CGFloat = 120
    static let timelineBarHeight: CGFloat = 30  // D4: lighter than 44pt
    static let phaseRowHeight: CGFloat = 148  // D3: taller for inline steppers

    // D1: New-Block-LOCAL ordered phase palette (fileprivate — never modifies
    // the public BlockPhaseColors API used by 5 other screens).
    //
    // Slot 0: ink (dark, highest contrast)
    // Slot 1: signal (coral, high energy)
    // Slot 2: ink @ 55% (medium dark)
    // Slot 3: ink @ 30% (light — pairs with ink label)
    // Slot 4: slate companion (desaturated warm-gray, paper-friendly)
    // Cycle when more phases than slots.
    // Deload: always solid muted (not a palette slot).
    static let paletteSlots: [Color] = [
        Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255),               // slot 0: full ink
        Color(red: 255 / 255, green: 77 / 255, blue: 46 / 255),              // slot 1: signal coral
        Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.55), // slot 2: ink@55%
        Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.30), // slot 3: ink@30%
        Color(red: 90 / 255, green: 87 / 255, blue: 80 / 255),               // slot 4: slate companion
    ]

    // Returns the palette fill color for a given phase order index.
    // Deload always gets the solid muted color regardless of index.
    static func paletteColor(forOrderIndex index: Int, isDeload: Bool) -> Color {
        if isDeload { return muted }
        return paletteSlots[index % paletteSlots.count]
    }

    // Returns the label color that has adequate contrast on top of the given palette slot.
    // Dark slots (ink, signal, slate) → white; light slot (ink@30%) → ink.
    static func paletteLabelColor(forOrderIndex index: Int, isDeload: Bool) -> Color {
        if isDeload { return paper }  // muted background → paper label
        let slot = index % paletteSlots.count
        return slot == 3 ? ink : Color.white
    }
    static let metricCellHeight: CGFloat = 36
    static let addPhaseSlotHeight: CGFloat = 70
    static let bottomActionHeight: CGFloat = 60
    static let bottomButtonHeight: CGFloat = 54
    static let scrollBottomClearance: CGFloat = 44
}

fileprivate enum NewBlockType {
    static let chrome = Font.custom("SpaceGrotesk-Bold", size: 11)
    static let chip = Font.custom("SpaceGrotesk-Bold", size: 9)
    static let label = Font.custom("SpaceGrotesk-Bold", size: 10)
    static let micro = Font.custom("SpaceGrotesk-Bold", size: 8)
    static let display = Font.custom("BebasNeue-Regular", size: 39)
    static let displayLarge = Font.custom("BebasNeue-Regular", size: 44)
    static let number = Font.custom("BebasNeue-Regular", size: 29)
    static let phaseIndex = Font.custom("BebasNeue-Regular", size: 28)
    static let phaseTitle = Font.custom("Geist-Regular", size: 18)
}

// MARK: - Preset model

internal enum NewBlockPreset: Hashable, CaseIterable {
    case blank
    case hypertrophyMeso
    case linearStrength
    case powerbuilding
    case offSeason
    case preMeet

    /// Uppercase chip label rendered in the template sheet and STARTING POINT band.
    var chipLabel: String {
        switch self {
        case .blank:           return "BLANK"
        case .hypertrophyMeso: return "HYPERTROPHY MESO"
        case .linearStrength:  return "LINEAR STRENGTH"
        case .powerbuilding:   return "POWERBUILDING"
        case .offSeason:       return "OFF-SEASON"
        case .preMeet:         return "PRE-MEET"
        }
    }

    /// Title-cased name applied to `draft.name` when the chip is tapped.
    /// `BLANK` returns the empty string so tapping it clears the draft name.
    var displayName: String {
        switch self {
        case .blank:           return ""
        case .hypertrophyMeso: return "Hypertrophy Meso"
        case .linearStrength:  return "Linear Strength"
        case .powerbuilding:   return "Powerbuilding"
        case .offSeason:       return "Off-Season"
        case .preMeet:         return "Pre-Meet"
        }
    }

    /// Case-insensitive match of an existing draft name against the preset
    /// list. Falls back to `.blank` when the name is empty or doesn't match.
    /// Used by `BlockBuilderView.onAppear` to seed initial chip selection
    /// for both the new-block path (empty name → `.blank`) and the edit
    /// path (existing block name matched against the preset display names).
    static func matching(name: String) -> NewBlockPreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .blank }
        let lower = trimmed.lowercased()
        for preset in NewBlockPreset.all where preset != .blank {
            if preset.displayName.lowercased() == lower {
                return preset
            }
        }
        return .blank
    }

    /// Spec-locked chip order: BLANK first, then the 5 named presets.
    static let all: [NewBlockPreset] = [
        .blank, .hypertrophyMeso, .linearStrength, .powerbuilding, .offSeason, .preMeet,
    ]
}

fileprivate struct NewBlockTopBar: View {
    let title: String
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NewBlockInkRule()

            HStack(alignment: .center) {
                Button(action: onBack) {
                    Text("< PROGRAM")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.chipTracking)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .frame(maxHeight: .infinity)

                Spacer()

                Button(action: onSave) {
                    Text("SAVE")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.chipTracking)
                        .foregroundStyle(NewBlockScreenTokens.signal)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NewBlockScreenTokens.sidePadding)
            .frame(height: NewBlockScreenTokens.topBarRowHeight)

            NewBlockInkRule()
        }
        .background(NewBlockScreenTokens.paper)
    }
}

// MARK: - Name Band

fileprivate struct NewBlockNameBand: View {
    @Bindable var draft: BlockDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BlockNameField(
                title: "BLOCK NAME",
                placeholder: "NAME YOUR BLOCK",
                text: $draft.name
            )
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: NewBlockScreenTokens.nameBandHeight, alignment: .topLeading)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }
}

fileprivate struct NewBlockPresetChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NewBlockType.chip)
                .tracking(1.8)
                .foregroundStyle(isSelected ? NewBlockScreenTokens.paper : NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 26)
                .padding(.horizontal, 9)
                .background(isSelected ? NewBlockScreenTokens.ink : Color.clear)
                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Sheet

fileprivate struct NewBlockTemplateSheet: View {
    let selected: NewBlockPreset
    let onSelect: (NewBlockPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose a preset or build from scratch.")
                    .font(NewBlockType.label)
                    .tracking(0.4)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                    .padding(.top, NewBlockScreenTokens.rowGap)
                    .padding(.bottom, NewBlockScreenTokens.sectionGap)

                Rectangle()
                    .fill(NewBlockScreenTokens.ink)
                    .frame(height: NewBlockScreenTokens.rule)

                VStack(spacing: 0) {
                    ForEach(NewBlockPreset.all, id: \.self) { preset in
                        let isSelected = preset == selected
                        let rowLabel = preset == .blank ? "FROM SCRATCH" : preset.chipLabel

                        Button {
                            onSelect(preset)
                            dismiss()
                        } label: {
                            HStack(spacing: NewBlockScreenTokens.rowGap) {
                                Text(rowLabel)
                                    .font(NewBlockType.chrome)
                                    .tracking(NewBlockScreenTokens.chipTracking)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if isSelected {
                                    Text("✓")
                                        .font(NewBlockType.chrome)
                                        .foregroundStyle(NewBlockScreenTokens.ink)
                                }
                            }
                            .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(isSelected ? NewBlockScreenTokens.faint : NewBlockScreenTokens.paper)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(NewBlockScreenTokens.hair)
                            .frame(height: NewBlockScreenTokens.rule)
                    }
                }

                Spacer()
            }
            .background(NewBlockScreenTokens.paper.ignoresSafeArea())
            .navigationTitle("Start From Template")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Metrics

fileprivate struct NewBlockMetricsBand: View {
    @Bindable var draft: BlockDraft
    let onEditWeeks: () -> Void
    let onEditDays: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // TOTAL WEEKS — read-only tappable cell
            Button(action: onEditWeeks) {
                VStack(alignment: .leading, spacing: NewBlockScreenTokens.tightGap) {
                    Text("TOTAL WEEKS")
                        .font(NewBlockType.label)
                        .tracking(NewBlockScreenTokens.labelTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)

                    Text("\(draft.totalWeeks)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)

                    Text("TAP TO EDIT PHASES")
                        .font(NewBlockType.micro)
                        .tracking(NewBlockScreenTokens.labelTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }
                .padding(.leading, NewBlockScreenTokens.sidePadding)
                .padding(.trailing, 14)
                .padding(.vertical, NewBlockScreenTokens.sectionGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Total weeks, \(draft.totalWeeks), edit phase durations")

            Rectangle()
                .fill(NewBlockScreenTokens.ink)
                .frame(width: NewBlockScreenTokens.rule)

            // DAYS PER WEEK — tappable cell
            Button(action: onEditDays) {
                VStack(alignment: .leading, spacing: NewBlockScreenTokens.tightGap) {
                    Text("DAYS PER WEEK")
                        .font(NewBlockType.label)
                        .tracking(NewBlockScreenTokens.labelTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)

                    Text("\(draft.daysPerWeek)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)

                    Text("TAP TO EDIT")
                        .font(NewBlockType.micro)
                        .tracking(NewBlockScreenTokens.labelTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }
                .padding(.leading, 14)
                .padding(.trailing, NewBlockScreenTokens.sidePadding)
                .padding(.vertical, NewBlockScreenTokens.sectionGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Days per week, \(draft.daysPerWeek), edit")
        }
        .frame(height: NewBlockScreenTokens.metricsHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }
}

fileprivate struct NewBlockStepperButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(NewBlockType.chrome)
                .tracking(0)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .frame(width: 32, height: 30)
                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Phase Header and Timeline

// D5: header right is now a stateful "Preset: {Custom|name} ▾" Menu routing through
// the existing Apply Preset? destructive confirm flow. "+ ADD PHASE" moved to D6 bottom row.
// D7b: also contains the REORDER/DONE toggle for the List edit mode.
fileprivate struct NewBlockPhasesHeader: View {
    let phaseCount: Int
    let selectedPreset: NewBlockPreset
    let isReordering: Bool
    let onToggleReorder: () -> Void
    let onSelectPreset: (NewBlockPreset) -> Void

    /// Display name for the current preset state.
    private var presetStateName: String {
        selectedPreset == .blank ? "Custom" : selectedPreset.displayName
    }

    var body: some View {
        HStack(spacing: NewBlockScreenTokens.rowGap) {
            Text("PHASES · \(phaseCount)")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)

            Spacer()

            // D7b: REORDER / DONE toggle — 44pt tap target, BRU-styled
            Button(action: onToggleReorder) {
                Text(isReordering ? "DONE" : "REORDER")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(isReordering ? NewBlockScreenTokens.signal : NewBlockScreenTokens.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            // D5: stateful preset selector — label reads "Preset: {Custom|name} ▾"
            Menu {
                ForEach(NewBlockPreset.all, id: \.self) { preset in
                    let label = preset == .blank ? "Custom" : preset.displayName
                    Button(label) {
                        onSelectPreset(preset)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Preset:")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.chipTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                    Text(presetStateName)
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.chipTracking)
                        .fontWeight(.bold)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NewBlockScreenTokens.ink)
                }
                .frame(minHeight: 44)  // 44pt touch target
            }
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(minHeight: NewBlockScreenTokens.phasesHeaderHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }
}

fileprivate struct NewBlockTimelinePreview: View {
    let phases: [BlockPhaseDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: NewBlockScreenTokens.sectionGap) {
            Text("PREVIEW")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)

            // D4: lighter bar — drop the 1.5pt full-ink stroke box; hair baseline only.
            GeometryReader { geometry in
                let total = max(CGFloat(phases.reduce(0) { $0 + $1.weeks }), 1)
                ZStack(alignment: .bottom) {
                    HStack(spacing: 0) {
                        // ForEach keys by \.draftID (stable UUID per unsaved draft).
                        ForEach(phases, id: \.draftID) { phase in
                            let orderIndex = phases.firstIndex(where: { $0.draftID == phase.draftID }) ?? 0
                            NewBlockTimelineSegment(phase: phase, orderIndex: orderIndex)
                                .frame(width: geometry.size.width * CGFloat(phase.weeks) / total)
                        }
                    }
                    // Hair-weight bottom baseline (replaces the 1.5pt full-ink outer box)
                    Rectangle()
                        .fill(NewBlockScreenTokens.hair)
                        .frame(height: NewBlockScreenTokens.rule)
                }
            }
            .frame(height: NewBlockScreenTokens.timelineBarHeight)

            // D4: cumulative week boundary ticks — one tick+label per phase boundary.
            // Computed outside the GeometryReader @ViewBuilder to avoid control-flow restrictions.
            let cumulativeWeeks: [Int] = phases.reduce(into: [Int]()) { acc, phase in
                acc.append((acc.last ?? 0) + phase.weeks)
            }
            let totalWeeks = max(phases.reduce(0) { $0 + $1.weeks }, 1)

            GeometryReader { tickGeo in
                let totalWeeksF = CGFloat(totalWeeks)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cumulativeWeeks.enumerated()), id: \.offset) { _, weekEnd in
                        let xFraction = CGFloat(weekEnd) / totalWeeksF
                        let xPos = tickGeo.size.width * xFraction
                        Group {
                            // Thin vertical tick at each phase boundary
                            Rectangle()
                                .fill(NewBlockScreenTokens.muted)
                                .frame(width: 1, height: 6)
                                .position(x: xPos, y: 3)
                            // W{n} label
                            Text("W\(weekEnd)")
                                .font(NewBlockType.micro)
                                .tracking(0.4)
                                .foregroundStyle(NewBlockScreenTokens.muted)
                                .fixedSize()
                                .position(
                                    x: min(max(xPos, 8), tickGeo.size.width - 8),
                                    y: 14
                                )
                        }
                    }
                }
            }
            .frame(height: 22)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.top, NewBlockScreenTokens.sectionGap)
        .padding(.bottom, NewBlockScreenTokens.tightGap)
        .frame(height: NewBlockScreenTokens.previewHeight, alignment: .top)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(height: NewBlockScreenTokens.rule)
        }
    }
}

fileprivate struct NewBlockTimelineSegment: View {
    let phase: BlockPhaseDraft
    let orderIndex: Int

    var body: some View {
        // D1: palette-ordered fill; deload = solid muted (no hatched stripes).
        // D4: narrow-label drop — GeometryReader measures rendered width; label is
        //     omitted entirely below the threshold (not just scaled down).
        let isDeload = phase.kind == .deload
        let fillColor = NewBlockScreenTokens.paletteColor(forOrderIndex: orderIndex, isDeload: isDeload)
        let labelColor = NewBlockScreenTokens.paletteLabelColor(forOrderIndex: orderIndex, isDeload: isDeload)

        GeometryReader { geo in
            let segmentWidth = geo.size.width
            let labelThreshold: CGFloat = 40  // D4: drop label when narrower than this

            ZStack(alignment: .leading) {
                fillColor
                if segmentWidth >= labelThreshold {
                    Text(NewBlockPhaseText.abbreviation(for: phase.kind))
                        .font(NewBlockType.label)
                        .tracking(1.2)
                        .foregroundStyle(labelColor)
                        .padding(.leading, 6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

fileprivate struct NewBlockDeloadStripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(NewBlockScreenTokens.paper))
            var x = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 6, y: 0))
                path.addLine(to: CGPoint(x: x + 6 + size.height, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(NewBlockScreenTokens.ink.opacity(0.15)))
                x += 12
            }
        }
    }
}

// MARK: - Phase Rows

fileprivate struct NewBlockPhaseEditorRow: View {
    @Bindable var draft: BlockPhaseDraft
    let displayIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: NewBlockScreenTokens.sectionGap) {
            // Header: number chip + title/subtitle + reorder glyph
            HStack(alignment: .top, spacing: NewBlockScreenTokens.sectionGap) {
                // D1: filled number chip — palette color keyed by order index.
                // Color is ALWAYS paired with the phase name beside it (colorblind-safe).
                let isDeload = draft.kind == .deload
                let chipFill = NewBlockScreenTokens.paletteColor(
                    forOrderIndex: displayIndex - 1, isDeload: isDeload)
                let chipLabel = NewBlockScreenTokens.paletteLabelColor(
                    forOrderIndex: displayIndex - 1, isDeload: isDeload)
                Text(String(format: "%02d", displayIndex))
                    .font(NewBlockType.phaseIndex)
                    .foregroundStyle(chipLabel)
                    .frame(width: 36, height: 36)
                    .background(chipFill)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: NewBlockScreenTokens.microGap) {
                    HStack(spacing: NewBlockScreenTokens.microGap) {
                        Text(NewBlockPhaseText.title(for: draft.kind))
                            .font(NewBlockType.phaseTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(NewBlockScreenTokens.ink)
                        if isDeload {
                            Text("DELOAD")
                                .font(NewBlockType.chip)
                                .tracking(1.4)
                                .foregroundStyle(NewBlockScreenTokens.paper)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(NewBlockScreenTokens.muted)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text(NewBlockPhaseText.subtitle(for: draft.kind))
                        .font(NewBlockType.label)
                        .tracking(1.2)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }

                Spacer()
                // D7b: decorative reorder glyph removed — native List move handle is the
                // single reorder cue (avoids double-handle confusion per D7 spec).
            }

            // D3: inline-editable metrics — no 1.5pt ink border boxes; hair dividers instead.
            // Each column: label (top) · value · −/+ stepper controls.
            HStack(spacing: 0) {
                // WEEKS
                NewBlockInlineMetricColumn(
                    label: "WEEKS",
                    value: "\(draft.weeks)",
                    onDecrement: {
                        draft.weeks = max(1, draft.weeks - 1)
                    },
                    onIncrement: {
                        draft.weeks = min(52, draft.weeks + 1)
                    }
                )

                // Hair divider
                Rectangle()
                    .fill(NewBlockScreenTokens.hair)
                    .frame(width: NewBlockScreenTokens.rule)

                // VOL
                NewBlockInlineMetricColumn(
                    label: "VOL",
                    value: NewBlockPhaseText.volumeValue(draft.volumeMultiplier),
                    onDecrement: {
                        let newVal = (draft.volumeMultiplier - 0.05)
                        draft.volumeMultiplier = (max(0.4, newVal) * 100).rounded() / 100
                    },
                    onIncrement: {
                        let newVal = (draft.volumeMultiplier + 0.05)
                        draft.volumeMultiplier = (min(1.6, newVal) * 100).rounded() / 100
                    }
                )

                // Hair divider
                Rectangle()
                    .fill(NewBlockScreenTokens.hair)
                    .frame(width: NewBlockScreenTokens.rule)

                // INT
                NewBlockInlineMetricColumn(
                    label: "INT",
                    value: NewBlockPhaseText.intensityValue(draft.intensityMultiplier),
                    onDecrement: {
                        let newVal = (draft.intensityMultiplier - 0.05)
                        draft.intensityMultiplier = (max(0.5, newVal) * 100).rounded() / 100
                    },
                    onIncrement: {
                        let newVal = (draft.intensityMultiplier + 0.05)
                        draft.intensityMultiplier = (min(1.0, newVal) * 100).rounded() / 100
                    }
                )
            }
            .frame(height: 56)
            .background(NewBlockScreenTokens.faint)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.top, NewBlockScreenTokens.sectionGap)
        .padding(.bottom, NewBlockScreenTokens.rowGap)
        .frame(height: NewBlockScreenTokens.phaseRowHeight, alignment: .top)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(height: NewBlockScreenTokens.rule)
        }
        .accessibilityLabel("Phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
    }
}

// D3: one reusable column for an inline-editable metric (label / value / −  +).
// No 1.5pt ink border box — calm label-over-value layout with shared hair dividers.
fileprivate struct NewBlockInlineMetricColumn: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(NewBlockType.micro)
                .tracking(1.4)
                .foregroundStyle(NewBlockScreenTokens.muted)

            Text(value)
                .font(NewBlockType.label)
                .tracking(0.6)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 4) {
                // 44pt touch target wrapping the 32×30 visual glyph
                NewBlockStepperButton(label: "−", action: onDecrement)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
                NewBlockStepperButton(label: "+", action: onIncrement)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

fileprivate enum NewBlockPhaseText {
    static func title(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:
            return "Accumulation"
        case .intensification:
            return "Intensification"
        case .realization:
            return "Realization"
        case .deload:
            return "Deload"
        }
    }

    static func subtitle(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:
            return "BUILD VOLUME"
        case .intensification:
            return "BUILD STRENGTH"
        case .realization:
            return "PEAK"
        case .deload:
            return "RECOVER"
        }
    }

    static func abbreviation(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:
            return "ACCUM"
        case .intensification:
            return "INTEN"
        case .realization:
            return "PEAK"
        case .deload:
            return "DELOAD"
        }
    }

    static func volumeValue(_ multiplier: Double) -> String {
        // D2: signed % vs base; ==1.0 renders as "Hold" (0-delta).
        if abs(multiplier - 1.0) < 0.001 {
            return "Hold"
        }
        let percent = Int(((multiplier - 1.0) * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    static func intensityValue(_ multiplier: Double) -> String {
        "\(Int((multiplier * 100).rounded()))%"
    }
}

// MARK: - Add Phase and Linked Routines

// D6: single full-width "+ ADD PHASE" row — opens the add-phase type picker sheet.
// "↘ PRESETS" removed (presets now in the header Menu). ONE literal "+" ADD PHASE" satisfies both guards.
fileprivate struct NewBlockAddPhaseSlot: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("+ ADD PHASE")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(
                    Rectangle()
                        .stroke(
                            NewBlockScreenTokens.ink,
                            style: StrokeStyle(lineWidth: 2, dash: [7, 4])
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, NewBlockScreenTokens.tightGap)
        .padding(.vertical, NewBlockScreenTokens.microGap)
        .frame(height: NewBlockScreenTokens.addPhaseSlotHeight)
        .background(NewBlockScreenTokens.paper)
    }
}

// D6: add-phase type picker — presented as a sheet; one row per BlockPhaseKind.
fileprivate struct NewBlockAddPhaseTypeSheet: View {
    let onSelect: (BlockPhaseKind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose a phase type to add.")
                    .font(NewBlockType.label)
                    .tracking(0.4)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                    .padding(.top, NewBlockScreenTokens.rowGap)
                    .padding(.bottom, NewBlockScreenTokens.sectionGap)

                Rectangle()
                    .fill(NewBlockScreenTokens.ink)
                    .frame(height: NewBlockScreenTokens.rule)

                // One 44pt row per BlockPhaseKind with a color swatch, title, and subtitle.
                ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                    let orderIndex = BlockPhaseKind.allCases.firstIndex(of: kind) ?? 0
                    let isDeload = kind == .deload
                    let swatchColor = NewBlockScreenTokens.paletteColor(
                        forOrderIndex: orderIndex, isDeload: isDeload)

                    Button {
                        onSelect(kind)
                        dismiss()
                    } label: {
                        HStack(spacing: NewBlockScreenTokens.sectionGap) {
                            // Color swatch matching the Chunk-A palette
                            RoundedRectangle(cornerRadius: 4)
                                .fill(swatchColor)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: NewBlockScreenTokens.microGap) {
                                Text(NewBlockPhaseText.title(for: kind))
                                    .font(NewBlockType.phaseTitle)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                Text(NewBlockPhaseText.subtitle(for: kind))
                                    .font(NewBlockType.label)
                                    .tracking(1.2)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, NewBlockScreenTokens.tightGap)
                        .background(NewBlockScreenTokens.paper)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(NewBlockScreenTokens.hair)
                        .frame(height: NewBlockScreenTokens.rule)
                }

                Spacer()
            }
            .background(NewBlockScreenTokens.paper.ignoresSafeArea())
            .navigationTitle("Add Phase")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

fileprivate struct NewBlockLinkedRoutinesBand: View {
    let count: Int

    var body: some View {
        HStack {
            Text("ROUTINES · \(count) LINKED")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)
            Spacer()
            Text("+ LINK")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(height: 31)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .top) {
            NewBlockInkRule()
        }
    }
}

// D7b: transient undo toast shown above the bottom action bar after a swipe-delete.
// Auto-dismisses when the 4s undoTask clears pendingDelete. "UNDO" is a ≥44pt Button.
fileprivate struct NewBlockUndoToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: NewBlockScreenTokens.rowGap) {
            Text("Phase deleted")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)

            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(width: NewBlockScreenTokens.rule)

            Button(action: onUndo) {
                Text("UNDO")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(NewBlockScreenTokens.signal)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.vertical, NewBlockScreenTokens.tightGap)
        .background(NewBlockScreenTokens.faint)
        .overlay(
            Rectangle()
                .stroke(NewBlockScreenTokens.hair, lineWidth: NewBlockScreenTokens.rule)
        )
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
    }
}

// MARK: - Bottom Bar

fileprivate struct NewBlockBottomActionBar: View {
    let canCreate: Bool
    let isEditing: Bool
    let onCancel: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NewBlockScreenTokens.ink)
                .frame(height: NewBlockScreenTokens.heavyRule)

            HStack(spacing: 0) {
                Button(action: onCancel) {
                    Text("CANCEL")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.ctaTracking)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(NewBlockScreenTokens.ink)
                    .frame(width: NewBlockScreenTokens.rule)

                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.ctaTracking)
                        .foregroundStyle(canCreate ? .white : NewBlockScreenTokens.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(canCreate ? NewBlockScreenTokens.ink : NewBlockScreenTokens.paper)
                }
                .buttonStyle(.plain)
                .disabled(!canCreate)
            }
            .frame(height: NewBlockScreenTokens.bottomButtonHeight)
        }
        .frame(height: NewBlockScreenTokens.bottomActionHeight)
        .background(NewBlockScreenTokens.paper)
    }

    private var primaryTitle: String {
        if !canCreate {
            return "NAME FIRST ↑"
        }
        return isEditing ? "SAVE CHANGES ▸" : "SAVE TEMPLATE ▸"
    }
}

// MARK: - Shared Rules

fileprivate struct NewBlockInkRule: View {
    var body: some View {
        Rectangle()
            .fill(NewBlockScreenTokens.ink)
            .frame(height: NewBlockScreenTokens.rule)
    }
}

// MARK: - Editor Sheets

fileprivate struct NewBlockDurationSheet: View {
    @Bindable var draft: BlockDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Title and live total
                VStack(alignment: .leading, spacing: NewBlockScreenTokens.microGap) {
                    Text("Edit Block Duration")
                        .font(NewBlockType.phaseTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(NewBlockScreenTokens.ink)

                    HStack(spacing: NewBlockScreenTokens.microGap) {
                        Text("TOTAL")
                            .font(NewBlockType.label)
                            .tracking(NewBlockScreenTokens.labelTracking)
                            .foregroundStyle(NewBlockScreenTokens.muted)
                        Text("\(draft.totalWeeks)")
                            .font(NewBlockType.number)
                            .foregroundStyle(NewBlockScreenTokens.ink)
                        Text("WKS")
                            .font(NewBlockType.label)
                            .tracking(NewBlockScreenTokens.labelTracking)
                            .foregroundStyle(NewBlockScreenTokens.muted)
                    }
                }
                .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                .padding(.top, NewBlockScreenTokens.sectionGap)
                .padding(.bottom, NewBlockScreenTokens.rowGap)

                NewBlockInkRule()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                            let phaseBinding = $draft.phases[index]
                            HStack(spacing: NewBlockScreenTokens.rowGap) {
                                Text(String(format: "%02d", index + 1))
                                    .font(NewBlockType.phaseIndex)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                    .frame(width: 32, alignment: .leading)

                                Text(NewBlockPhaseText.title(for: phase.kind))
                                    .font(NewBlockType.phaseTitle)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                NewBlockStepperButton(label: "−") {
                                    phaseBinding.weeks.wrappedValue = max(1, phase.weeks - 1)
                                }
                                Text("\(phase.weeks)")
                                    .font(NewBlockType.number)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                    .frame(width: 28, alignment: .center)
                                NewBlockStepperButton(label: "+") {
                                    phaseBinding.weeks.wrappedValue = phase.weeks + 1
                                }
                            }
                            .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                            .frame(height: 56)
                            .background(NewBlockScreenTokens.paper)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(NewBlockScreenTokens.hair)
                                    .frame(height: NewBlockScreenTokens.rule)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                NewBlockInkRule()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.ctaTracking)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: NewBlockScreenTokens.bottomButtonHeight)
                }
                .buttonStyle(.plain)
                .background(NewBlockScreenTokens.paper)
            }
            .background(NewBlockScreenTokens.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
    }
}

fileprivate struct NewBlockDaysSheet: View {
    @Bindable var draft: BlockDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text("Days Per Week")
                    .font(NewBlockType.phaseTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                    .padding(.top, NewBlockScreenTokens.sectionGap)
                    .padding(.bottom, NewBlockScreenTokens.rowGap)

                NewBlockInkRule()

                // 1-7 BRU-styled selector
                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { day in
                        let isSelected = draft.daysPerWeek == day
                        Button {
                            draft.daysPerWeek = day
                        } label: {
                            Text("\(day)")
                                .font(NewBlockType.number)
                                .foregroundStyle(isSelected ? NewBlockScreenTokens.paper : NewBlockScreenTokens.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isSelected ? NewBlockScreenTokens.ink : Color.clear)
                                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                .padding(.vertical, NewBlockScreenTokens.sectionGap)

                // Recommended hint
                Text("Recommended: 3-6")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                    .padding(.bottom, NewBlockScreenTokens.sectionGap)

                Spacer(minLength: 0)

                NewBlockInkRule()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.ctaTracking)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: NewBlockScreenTokens.bottomButtonHeight)
                }
                .buttonStyle(.plain)
                .background(NewBlockScreenTokens.paper)
            }
            .background(NewBlockScreenTokens.paper.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Previews

#if DEBUG
#Preview("New Block — blank") {
    BlockBuilderView(draft: BlockDraft.newBlock())
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("New Block — named") {
    let draft = BlockDraft.newBlock()
    draft.name = "Hypertrophy Meso"
    return BlockBuilderView(draft: draft)
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
#endif
