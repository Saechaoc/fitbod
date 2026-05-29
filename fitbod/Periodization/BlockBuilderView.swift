//
//  BlockBuilderView.swift
//  fitbod
//
//  Full-screen New Block editor matching bru-screens/New-block/new-block.png.
//

import Charts
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
                            onEditWeeks: { presentingDurationSheet = true }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        // Progression chart (replaces timeline preview)
                        NewBlockProgressionChart(phases: draft.phases)
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
                                },
                                onAddPhase: { presentingAddPhaseTypePicker = true }
                            )
                            .listRowInsets(EdgeInsets())
                        }

                        // ── Bottom rows ─────────────────────────────────────────────

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
    static let phaseRowHeight: CGFloat = 100  // read-only stat columns; no steppers needed

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

// Two-cell metrics card matching bru-screens/New-block/final-design-2.png:
// a single rounded card split by a hairline divider. TOTAL WEEKS is read-only
// (it is the sum of phase durations) and taps through to the duration editor;
// DAYS PER WEEK is edited inline with − / + steppers (the design shows the
// steppers here — it is a free value, not derived).
fileprivate struct NewBlockMetricsBand: View {
    @Bindable var draft: BlockDraft
    let onEditWeeks: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // TOTAL WEEKS — computed from phase durations; tap opens the duration editor.
            Button(action: onEditWeeks) {
                VStack(alignment: .leading, spacing: NewBlockScreenTokens.tightGap) {
                    Text("TOTAL WEEKS")
                        .font(NewBlockType.label)
                        .tracking(NewBlockScreenTokens.labelTracking)
                        .foregroundStyle(NewBlockScreenTokens.muted)

                    Text("\(draft.totalWeeks)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, NewBlockScreenTokens.sectionGap)
                .padding(.vertical, NewBlockScreenTokens.rowGap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Total weeks, \(draft.totalWeeks), edit phase durations")

            // Hairline divider between the two cells.
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(width: NewBlockScreenTokens.rule)

            // DAYS PER WEEK — inline − / + steppers (clamp 1...7, mirrors the days sheet's range).
            VStack(alignment: .leading, spacing: NewBlockScreenTokens.tightGap) {
                Text("DAYS PER WEEK")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                HStack(spacing: NewBlockScreenTokens.rowGap) {
                    NewBlockStepperButton(label: "−") {
                        draft.daysPerWeek = max(1, draft.daysPerWeek - 1)
                    }
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Decrease days per week")

                    Text("\(draft.daysPerWeek)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(minWidth: 28)
                        .accessibilityHidden(true)

                    NewBlockStepperButton(label: "+") {
                        draft.daysPerWeek = min(7, draft.daysPerWeek + 1)
                    }
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Increase days per week")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, NewBlockScreenTokens.sectionGap)
            .padding(.vertical, NewBlockScreenTokens.rowGap)
            .accessibilityElement(children: .contain)
            .accessibilityValue("\(draft.daysPerWeek) days per week")
        }
        .frame(minHeight: NewBlockScreenTokens.metricsHeight)
        .background(NewBlockScreenTokens.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(NewBlockScreenTokens.hair, lineWidth: NewBlockScreenTokens.rule)
        )
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.vertical, NewBlockScreenTokens.rowGap)
        .frame(maxWidth: .infinity)
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

// Header: PHASES · N title, REORDER toggle, Preset menu, and coral "+ ADD PHASE" accent action.
// D7b: REORDER/DONE toggle gates .onMove. Preset menu routes through the destructive confirm.
// "+ ADD PHASE" is the rightmost accent action wired to the add-phase type picker sheet.
fileprivate struct NewBlockPhasesHeader: View {
    let phaseCount: Int
    let selectedPreset: NewBlockPreset
    let isReordering: Bool
    let onToggleReorder: () -> Void
    let onSelectPreset: (NewBlockPreset) -> Void
    let onAddPhase: () -> Void

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

            // Stateful preset selector — label reads "Preset: {Custom|name} ▾"
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

            // Coral "+ ADD PHASE" — rightmost accent, ≥44pt target, wired to type picker
            Button(action: onAddPhase) {
                Text("+ ADD PHASE")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(NewBlockScreenTokens.signal)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(minHeight: NewBlockScreenTokens.phasesHeaderHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }
}

// MARK: - Progression Chart

/// Chart data point for volume/intensity progression lines.
private struct NewBlockProgressionPoint: Identifiable {
    let id = UUID()
    let week: Int
    let value: Double
    let series: String
    let kind: BlockPhaseKind
}

/// Swift Charts progression card — replaces the old timeline preview.
/// Shows Volume (solid line + points) and Intensity (dashed line) across
/// all phases with proportional top-phase labels and W1..Wn x-axis ticks.
fileprivate struct NewBlockProgressionChart: View {
    let phases: [BlockPhaseDraft]

    /// Expand phases into per-week data points.
    private var points: [NewBlockProgressionPoint] {
        var result: [NewBlockProgressionPoint] = []
        var weekOffset = 0
        for phase in phases {
            for w in 0..<phase.weeks {
                let week = weekOffset + w + 1
                result.append(NewBlockProgressionPoint(
                    week: week,
                    value: phase.volumeMultiplier * 100,
                    series: "Volume",
                    kind: phase.kind
                ))
                result.append(NewBlockProgressionPoint(
                    week: week,
                    value: phase.intensityMultiplier * 100,
                    series: "Intensity",
                    kind: phase.kind
                ))
            }
            weekOffset += phase.weeks
        }
        return result
    }

    /// Cumulative week boundaries for x-axis marks.
    private var cumulativeBoundaries: [Int] {
        phases.reduce(into: [Int]()) { acc, phase in
            acc.append((acc.last ?? 0) + phase.weeks)
        }
    }

    private var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NewBlockScreenTokens.sectionGap) {
            // Section label
            Text("PROGRESSION OVERVIEW")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)

            // Hand-rolled legend (avoids fighting chartForegroundStyleScale)
            HStack(spacing: NewBlockScreenTokens.sectionGap) {
                HStack(spacing: 4) {
                    // Solid volume line indicator
                    Rectangle()
                        .fill(NewBlockScreenTokens.ink)
                        .frame(width: 16, height: 2)
                    Circle()
                        .fill(NewBlockScreenTokens.ink)
                        .frame(width: 5, height: 5)
                    Text("Volume")
                        .font(NewBlockType.micro)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                }
                HStack(spacing: 4) {
                    // Dashed intensity line indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(NewBlockScreenTokens.muted)
                                .frame(width: 4, height: 2)
                        }
                    }
                    Text("Intensity")
                        .font(NewBlockType.micro)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }
            }

            if phases.isEmpty {
                // Empty state placeholder
                Text("Add phases to preview progression")
                    .font(NewBlockType.label)
                    .tracking(0.6)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: NewBlockScreenTokens.previewHeight)
            } else {
                // Top phase abbreviation labels (proportional width)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(phases, id: \.draftID) { phase in
                            Text(NewBlockPhaseText.abbreviation(for: phase.kind))
                                .font(NewBlockType.micro)
                                .tracking(0.8)
                                .foregroundStyle(NewBlockScreenTokens.muted)
                                .frame(
                                    width: totalWeeks > 0
                                        ? geo.size.width * CGFloat(phase.weeks) / CGFloat(totalWeeks)
                                        : 0,
                                    alignment: .center
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                .frame(height: 14)

                // The chart
                Chart {
                    ForEach(points.filter { $0.series == "Volume" }) { pt in
                        LineMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value),
                            series: .value("Series", pt.series)
                        )
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value)
                        )
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .symbolSize(24)
                    }
                    ForEach(points.filter { $0.series == "Intensity" }) { pt in
                        LineMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value),
                            series: .value("Series", pt.series)
                        )
                        .foregroundStyle(NewBlockScreenTokens.muted)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: cumulativeBoundaries) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel {
                                Text("W\(week)")
                                    .font(NewBlockType.micro)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                            }
                            AxisTick(stroke: StrokeStyle(lineWidth: 1))
                                .foregroundStyle(NewBlockScreenTokens.muted)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(NewBlockScreenTokens.hair)
                    }
                }
                .frame(height: NewBlockScreenTokens.previewHeight)
            }
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.top, NewBlockScreenTokens.sectionGap)
        .padding(.bottom, NewBlockScreenTokens.tightGap)
        .background(NewBlockScreenTokens.paper)
        .overlay(
            Rectangle()
                .stroke(NewBlockScreenTokens.ink, lineWidth: 1)
                .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                .padding(.top, NewBlockScreenTokens.sectionGap)
                .padding(.bottom, NewBlockScreenTokens.tightGap),
            alignment: .center
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(height: NewBlockScreenTokens.rule)
        }
    }
}

// MARK: - Phase Rows

fileprivate struct NewBlockPhaseEditorRow: View {
    @Bindable var draft: BlockPhaseDraft
    let displayIndex: Int

    @State private var presentingEditor = false

    var body: some View {
        HStack(alignment: .center, spacing: NewBlockScreenTokens.sectionGap) {
            // Semantic badge color keyed by phase kind.
            // Color is ALWAYS paired with the phase name beside it (colorblind-safe).
            let isDeload = draft.kind == .deload
            let chipFill = BlockPhaseColors.badgeColor(for: draft.kind)
            let chipLabel = BlockPhaseColors.badgeLabelColor(for: draft.kind)
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

            // Read-only stat columns: WEEKS / VOL / INT
            HStack(spacing: NewBlockScreenTokens.rowGap) {
                NewBlockReadOnlyStatColumn(
                    label: "WEEKS",
                    value: "\(draft.weeks)"
                )
                Rectangle()
                    .fill(NewBlockScreenTokens.hair)
                    .frame(width: NewBlockScreenTokens.rule, height: 28)
                NewBlockReadOnlyStatColumn(
                    label: "VOL",
                    value: NewBlockPhaseText.volumeValue(draft.volumeMultiplier)
                )
                Rectangle()
                    .fill(NewBlockScreenTokens.hair)
                    .frame(width: NewBlockScreenTokens.rule, height: 28)
                NewBlockReadOnlyStatColumn(
                    label: "INT",
                    value: NewBlockPhaseText.intensityValue(draft.intensityMultiplier)
                )
            }
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(height: NewBlockScreenTokens.phaseRowHeight)
        .background(NewBlockScreenTokens.paper)
        .contentShape(Rectangle())
        .onTapGesture { presentingEditor = true }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(height: NewBlockScreenTokens.rule)
        }
        .accessibilityLabel("Phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
        .sheet(isPresented: $presentingEditor) {
            NewBlockPhaseEditorSheet(draft: draft)
        }
    }
}

/// Read-only right-aligned label-over-value stat column for the phase row.
fileprivate struct NewBlockReadOnlyStatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: NewBlockScreenTokens.microGap) {
            Text(label)
                .font(NewBlockType.micro)
                .tracking(1.4)
                .foregroundStyle(NewBlockScreenTokens.muted)
            Text(value)
                .font(NewBlockType.number)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
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
            return "Peak"
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
            return "SHARPEN OUTPUT"
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

// MARK: - Per-Phase Editor Sheet

/// BRU-styled sheet for editing a single phase's weeks, volume, and intensity.
/// Mirrors NewBlockDurationSheet: NavigationStack,
/// .presentationDetents([.medium]), NewBlockInkRule separators, plain "Done" dismiss.
/// Uses row-local @State identity via draftID — never BlockPhaseDraft.id (nil until saved).
fileprivate struct NewBlockPhaseEditorSheet: View {
    @Bindable var draft: BlockPhaseDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(NewBlockPhaseText.title(for: draft.kind))
                    .font(NewBlockType.phaseTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .padding(.horizontal, NewBlockScreenTokens.sidePadding)
                    .padding(.top, NewBlockScreenTokens.sectionGap)
                    .padding(.bottom, NewBlockScreenTokens.rowGap)

                NewBlockInkRule()

                ScrollView {
                    VStack(spacing: 0) {
                        // WEEKS row
                        HStack(spacing: NewBlockScreenTokens.rowGap) {
                            Text("WEEKS")
                                .font(NewBlockType.label)
                                .tracking(NewBlockScreenTokens.labelTracking)
                                .foregroundStyle(NewBlockScreenTokens.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            NewBlockStepperButton(label: "−") {
                                draft.weeks = max(1, draft.weeks - 1)
                            }
                            Text("\(draft.weeks)")
                                .font(NewBlockType.number)
                                .foregroundStyle(NewBlockScreenTokens.ink)
                                .frame(width: 36, alignment: .center)
                            NewBlockStepperButton(label: "+") {
                                draft.weeks = min(52, draft.weeks + 1)
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

                        // VOL row
                        HStack(spacing: NewBlockScreenTokens.rowGap) {
                            VStack(alignment: .leading, spacing: NewBlockScreenTokens.microGap) {
                                Text("VOLUME")
                                    .font(NewBlockType.label)
                                    .tracking(NewBlockScreenTokens.labelTracking)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                                Text("vs base")
                                    .font(NewBlockType.micro)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            NewBlockStepperButton(label: "−") {
                                let newVal = draft.volumeMultiplier - 0.05
                                draft.volumeMultiplier = (max(0.4, newVal) * 100).rounded() / 100
                            }
                            Text(NewBlockPhaseText.volumeValue(draft.volumeMultiplier))
                                .font(NewBlockType.number)
                                .foregroundStyle(NewBlockScreenTokens.ink)
                                .frame(width: 52, alignment: .center)
                            NewBlockStepperButton(label: "+") {
                                let newVal = draft.volumeMultiplier + 0.05
                                draft.volumeMultiplier = (min(1.6, newVal) * 100).rounded() / 100
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

                        // INT row
                        HStack(spacing: NewBlockScreenTokens.rowGap) {
                            VStack(alignment: .leading, spacing: NewBlockScreenTokens.microGap) {
                                Text("INTENSITY")
                                    .font(NewBlockType.label)
                                    .tracking(NewBlockScreenTokens.labelTracking)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                                Text("% of training max")
                                    .font(NewBlockType.micro)
                                    .foregroundStyle(NewBlockScreenTokens.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            NewBlockStepperButton(label: "−") {
                                let newVal = draft.intensityMultiplier - 0.05
                                draft.intensityMultiplier = (max(0.5, newVal) * 100).rounded() / 100
                            }
                            Text(NewBlockPhaseText.intensityValue(draft.intensityMultiplier))
                                .font(NewBlockType.number)
                                .foregroundStyle(NewBlockScreenTokens.ink)
                                .frame(width: 52, alignment: .center)
                            NewBlockStepperButton(label: "+") {
                                let newVal = draft.intensityMultiplier + 0.05
                                draft.intensityMultiplier = (min(1.0, newVal) * 100).rounded() / 100
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

// MARK: - Add Phase and Linked Routines

// Add-phase type picker — presented as a sheet; one row per BlockPhaseKind.
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
                    let swatchColor = BlockPhaseColors.badgeColor(for: kind)

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
