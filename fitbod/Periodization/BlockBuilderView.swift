//
//  BlockBuilderView.swift
//  fitbod
//
//  Full-screen New Block editor matching bru-screens/New-block/final-design.png.
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

                    // 260528-vi2: ScrollView/LazyVStack card layout replaces the old
                    // List(.plain) table. The LazyVStack owns the screenMargin horizontal
                    // padding — child bands must NOT re-apply their own horizontal padding
                    // to avoid the double-margin (~36pt) trap.
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: NewBlockScreenTokens.cardGap) {
                            // Large name header (not a card — floats on paper)
                            NewBlockNameBand(draft: draft)

                            // Stats card
                            NewBlockMetricsBand(
                                draft: draft,
                                onEditWeeks: { presentingDurationSheet = true }
                            )

                            // Progression chart card
                            NewBlockProgressionChart(phases: draft.phases)

                            // Phases header row (plain, on paper — no card)
                            NewBlockPhasesHeader(
                                phaseCount: draft.phases.count,
                                onAddPhase: { presentingAddPhaseTypePicker = true }
                            )

                            // Phase cards
                            ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                                NewBlockPhaseEditorRow(
                                    draft: phase,
                                    displayIndex: index + 1,
                                    onDelete: { beginPendingDelete(phase) },
                                    onMoveUp: { movePhase(phase, by: -1) },
                                    onMoveDown: { movePhase(phase, by: 1) }
                                )
                            }

                            // Conditional linked-routines band
                            if draft.isValid {
                                NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)
                            }

                            // Error band
                            if let saveError {
                                errorBand(saveError)
                            }

                            // Bottom clearance: keeps last card visible above the action bar
                            Color.clear
                                .frame(height: NewBlockScreenTokens.bottomActionHeight
                                    + NewBlockScreenTokens.scrollBottomClearance)
                        }
                        .padding(.horizontal, NewBlockScreenTokens.screenMargin)
                        .padding(.top, NewBlockScreenTokens.cardGap)
                    }
                    .scrollIndicators(.hidden)
                    .background(NewBlockScreenTokens.paper)
                }

                // Transient undo toast — visible above the action bar while
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

    // 260528-vi2: reorder helper — replaces the removed .onMove List affordance.
    // Context menu "Move Up" / "Move Down" buttons call this.
    private func movePhase(_ phase: BlockPhaseDraft, by offset: Int) {
        guard let i = draft.phases.firstIndex(where: { $0.draftID == phase.draftID }) else { return }
        let j = i + offset
        guard draft.phases.indices.contains(j) else { return }
        draft.phases.swapAt(i, j)
    }

    // Swipe-delete undo affordance.
    // beginPendingDelete captures {phase, index}, removes from draft.phases, cancels any
    // prior undoTask, and starts a 4s @MainActor Task that clears pendingDelete on timeout.
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

    // 260528-vi2: error band — rendered as a subtle rounded note (no hard ink rules).
    private func errorBand(_ message: String) -> some View {
        Text(message)
            .font(NewBlockType.label)
            .tracking(NewBlockScreenTokens.labelTracking)
            .foregroundStyle(NewBlockScreenTokens.signal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NewBlockScreenTokens.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: NewBlockScreenTokens.phaseCardRadius, style: .continuous)
                    .fill(NewBlockScreenTokens.faint)
            )
    }
}

// MARK: - Tokens

fileprivate enum NewBlockScreenTokens {
    static let paper  = Color(red: 240 / 255, green: 237 / 255, blue: 229 / 255)
    static let ink    = Color(red: 10 / 255,  green: 10 / 255,  blue: 10 / 255)
    static let muted  = Color(red: 126 / 255, green: 123 / 255, blue: 114 / 255)
    static let hair   = Color(red: 212 / 255, green: 209 / 255, blue: 202 / 255)
    static let faint  = Color(red: 232 / 255, green: 229 / 255, blue: 221 / 255)
    static let signal = Color(red: 255 / 255, green: 77 / 255,  blue: 46 / 255)

    // Card surface system (rounded-card restyle 260528-vi2)
    static let card        = Color(red: 252 / 255, green: 251 / 255, blue: 248 / 255) // #FCFBF8 warm white
    static let cardStroke  = Color(red: 225 / 255, green: 222 / 255, blue: 214 / 255) // #E1DED6 faint border
    static let cardShadow  = Color.black.opacity(0.06)

    static let screenMargin: CGFloat    = 20  // uniform L/R margin for ALL main-scroll content
    static let cardGap: CGFloat         = 14  // vertical spacing between stacked cards
    static let cardPadding: CGFloat     = 16  // internal card padding
    static let cardRadius: CGFloat      = 18  // stats + chart big cards
    static let phaseCardRadius: CGFloat = 14  // phase cards
    static let cardStrokeWidth: CGFloat = 0.75

    // Legacy spacing tokens (kept for sheet internals and other reuse)
    static let sidePadding: CGFloat  = 16
    static let rule: CGFloat         = 1
    static let heavyRule: CGFloat    = 3
    static let labelTracking: CGFloat = 2.2
    static let chipTracking: CGFloat  = 2.1

    static let microGap:   CGFloat = 4
    static let tightGap:   CGFloat = 6
    static let rowGap:     CGFloat = 8
    static let sectionGap: CGFloat = 10

    static let ctaTracking: CGFloat = 2.8

    static let topBarRowHeight: CGFloat   = 50
    static let nameBandHeight: CGFloat    = 80
    static let metricsHeight: CGFloat     = 92
    static let phasesHeaderHeight: CGFloat = 36
    static let previewHeight: CGFloat     = 120
    static let timelineBarHeight: CGFloat = 30
    static let phaseRowHeight: CGFloat    = 100

    static let metricCellHeight: CGFloat   = 36
    static let addPhaseSlotHeight: CGFloat = 70
    // 260528-vi2: bumped 60 → 72 to clear the new taller bottom bar (52pt button + ~20pt padding)
    static let bottomActionHeight: CGFloat  = 72
    static let bottomButtonHeight: CGFloat  = 54
    static let scrollBottomClearance: CGFloat = 44
}

fileprivate enum NewBlockType {
    static let chrome = Font.custom("SpaceGrotesk-Bold", size: 11)
    static let chip   = Font.custom("SpaceGrotesk-Bold", size: 9)
    static let label  = Font.custom("SpaceGrotesk-Bold", size: 10)
    static let micro  = Font.custom("SpaceGrotesk-Bold", size: 8)
    static let display      = Font.custom("BebasNeue-Regular", size: 39)
    static let displayLarge = Font.custom("BebasNeue-Regular", size: 44)
    static let number       = Font.custom("BebasNeue-Regular", size: 29)
    static let phaseIndex   = Font.custom("BebasNeue-Regular", size: 28)
    static let phaseTitle   = Font.custom("Geist-Regular", size: 18)
}

// MARK: - bruCard modifier

// 260528-vi2: shared card surface modifier — warm white fill, faint border, soft drop shadow.
private extension View {
    func bruCard(radius: CGFloat = NewBlockScreenTokens.cardRadius) -> some View {
        self
            .background(NewBlockScreenTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(NewBlockScreenTokens.cardStroke,
                            lineWidth: NewBlockScreenTokens.cardStrokeWidth)
            )
            .shadow(color: NewBlockScreenTokens.cardShadow, radius: 10, x: 0, y: 3)
    }
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

// MARK: - Top Bar

// 260528-vi2: no ink rules; sits on paper, borderless.
fileprivate struct NewBlockTopBar: View {
    let title: String
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
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
        .background(NewBlockScreenTokens.paper)
    }
}

// MARK: - Name Band

// 260528-vi2: large display name with trailing pencil icon; no ink rules; no height clamp.
// The LazyVStack owns screenMargin — this band does NOT add its own horizontal padding.
fileprivate struct NewBlockNameBand: View {
    @Bindable var draft: BlockDraft

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            BlockNameField(
                title: "BLOCK NAME",
                placeholder: "NAME YOUR BLOCK",
                text: $draft.name
            )

            // Trailing pencil affordance (visual; field is tappable via BlockNameField)
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18))
                .foregroundStyle(NewBlockScreenTokens.muted)
                .padding(.top, 28)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(NewBlockScreenTokens.paper)
    }
}

// MARK: - Preset Chip (kept for fidelity test — may be visually unused)

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

// MARK: - Template Sheet (kept for fidelity test — wired to presentingTemplateSheet)

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

// MARK: - Metrics Band

// 260528-vi2: two-cell metrics rendered as a floating white bruCard.
// The LazyVStack owns screenMargin — no horizontal padding here.
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
                .padding(.horizontal, NewBlockScreenTokens.cardPadding)
                .padding(.vertical, NewBlockScreenTokens.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Total weeks, \(draft.totalWeeks), edit phase durations")

            // Inset hairline divider between the two cells
            Rectangle()
                .fill(NewBlockScreenTokens.hair)
                .frame(width: NewBlockScreenTokens.rule)
                .padding(.vertical, 10)

            // DAYS PER WEEK — inline − / + steppers (clamp 1...7)
            VStack(alignment: .leading, spacing: NewBlockScreenTokens.tightGap) {
                Text("DAYS PER WEEK")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                HStack(spacing: NewBlockScreenTokens.sectionGap) {
                    NewBlockRoundStepper(label: "−") {
                        draft.daysPerWeek = max(1, draft.daysPerWeek - 1)
                    }
                    .accessibilityLabel("Decrease days per week")

                    Text("\(draft.daysPerWeek)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(minWidth: 24)
                        .multilineTextAlignment(.center)
                        .accessibilityHidden(true)

                    NewBlockRoundStepper(label: "+") {
                        draft.daysPerWeek = min(7, draft.daysPerWeek + 1)
                    }
                    .accessibilityLabel("Increase days per week")
                }
                // Pull the centered first button flush-left so the − aligns under
                // the label, matching the TOTAL WEEKS number's left edge.
                .padding(.leading, -6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, NewBlockScreenTokens.cardPadding)
            .padding(.vertical, NewBlockScreenTokens.cardPadding)
            .accessibilityElement(children: .contain)
            .accessibilityValue("\(draft.daysPerWeek) days per week")
        }
        .frame(minHeight: NewBlockScreenTokens.metricsHeight)
        .bruCard()
    }
}

// Rounded, borderless ± control for the metrics DAYS PER WEEK cell (final-design-2):
// a soft filled circle (no outline) with the glyph centered in a 44pt tap target.
// Distinct from NewBlockStepperButton (the sharp outlined stepper the editor sheets use).
fileprivate struct NewBlockRoundStepper: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(NewBlockScreenTokens.ink)
                .frame(width: 32, height: 32)
                .background(NewBlockScreenTokens.hair, in: Circle())
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)   // centered tap target — glyph stays visually centered
        .contentShape(Circle())
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

// MARK: - Phases Header

// 260528-vi2: simplified to PHASES · N (left) + + ADD PHASE (right, coral).
// REORDER/DONE toggle and Preset menu removed — reorder is in per-card context menu.
fileprivate struct NewBlockPhasesHeader: View {
    let phaseCount: Int
    let onAddPhase: () -> Void

    var body: some View {
        HStack(spacing: NewBlockScreenTokens.rowGap) {
            Text("PHASES · \(phaseCount)")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)

            Spacer()

            // Coral "+ ADD PHASE" — rightmost accent, ≥44pt target
            Button(action: onAddPhase) {
                Text("+ ADD PHASE")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(NewBlockScreenTokens.signal)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: NewBlockScreenTokens.phasesHeaderHeight)
        .background(NewBlockScreenTokens.paper)
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

/// Phase band data for colored background regions.
private struct NewBlockPhaseBand: Identifiable {
    let id = UUID()
    let start: Int
    let end: Int
    let kind: BlockPhaseKind
}

/// Swift Charts progression card — shows Volume (solid) and Intensity (dashed) lines
/// with faint colored phase-band regions behind them. Wrapped in a bruCard.
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

    /// Phase bands for colored background regions (start..end in cumulative weeks).
    private var phaseBands: [NewBlockPhaseBand] {
        var bands: [NewBlockPhaseBand] = []
        var offset = 0
        for phase in phases {
            let start = offset
            let end = offset + phase.weeks
            bands.append(NewBlockPhaseBand(start: start, end: end, kind: phase.kind))
            offset = end
        }
        return bands
    }

    private var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    /// Y range spanning data values for the band height.
    private var yLow: Double { 30 }
    private var yHigh: Double { 130 }

    var body: some View {
        VStack(alignment: .leading, spacing: NewBlockScreenTokens.sectionGap) {
            // Section label + legend on the same row
            HStack {
                Text("PROGRESSION OVERVIEW")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                Spacer()

                // Hand-rolled legend (top-right)
                HStack(spacing: NewBlockScreenTokens.sectionGap) {
                    HStack(spacing: 4) {
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
            }

            if phases.isEmpty {
                Text("Add phases to preview progression")
                    .font(NewBlockType.label)
                    .tracking(0.6)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: NewBlockScreenTokens.previewHeight)
            } else {
                // Top phase abbreviation labels (proportional width) — required: ForEach(phases, id: \.draftID)
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

                // The chart with colored phase-band regions behind the lines
                Chart {
                    // Faint colored background bands per phase
                    ForEach(phaseBands) { band in
                        RectangleMark(
                            xStart: .value("s", band.start),
                            xEnd: .value("e", band.end),
                            yStart: .value("lo", yLow),
                            yEnd: .value("hi", yHigh)
                        )
                        .foregroundStyle(
                            BlockPhaseColors.badgeColor(for: band.kind).opacity(0.12)
                        )
                    }

                    // Volume line (solid ink + points) ON TOP of bands
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
                    // Intensity line (dashed muted) ON TOP of bands
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
        .padding(NewBlockScreenTokens.cardPadding)
        .bruCard()
    }
}

// MARK: - Phase Rows

// 260528-vi2: compact rounded phase card with context menu for reorder + delete.
// Each phase is its own ~68pt bruCard. Context menu replaces swipe-delete + REORDER.
fileprivate struct NewBlockPhaseEditorRow: View {
    @Bindable var draft: BlockPhaseDraft
    let displayIndex: Int
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var presentingEditor = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Semantic badge (phase color + Bebas index)
            let chipFill  = BlockPhaseColors.badgeColor(for: draft.kind)
            let chipLabel = BlockPhaseColors.badgeLabelColor(for: draft.kind)
            Text(String(format: "%02d", displayIndex))
                .font(NewBlockType.phaseIndex)
                .foregroundStyle(chipLabel)
                .frame(width: 36, height: 36)
                .background(chipFill)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            // Phase title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(NewBlockPhaseText.title(for: draft.kind))
                    .font(NewBlockType.phaseTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(NewBlockScreenTokens.ink)

                Text(NewBlockPhaseText.subtitle(for: draft.kind))
                    .font(NewBlockType.label)
                    .tracking(1.2)
                    .foregroundStyle(NewBlockScreenTokens.muted)
            }

            Spacer()

            // Compact stat columns: WEEKS / VOL / INT (no vertical hairlines)
            HStack(spacing: 10) {
                NewBlockReadOnlyStatColumn(
                    label: "WEEKS",
                    value: "\(draft.weeks)"
                )
                NewBlockReadOnlyStatColumn(
                    label: "VOL",
                    value: NewBlockPhaseText.volumeValue(draft.volumeMultiplier)
                )
                NewBlockReadOnlyStatColumn(
                    label: "INT",
                    value: NewBlockPhaseText.intensityValue(draft.intensityMultiplier)
                )
            }

            // Chevron affordance
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NewBlockScreenTokens.muted)
        }
        .padding(.horizontal, NewBlockScreenTokens.cardPadding)
        .padding(.vertical, 14)
        .bruCard(radius: NewBlockScreenTokens.phaseCardRadius)
        .contentShape(Rectangle())
        .onTapGesture { presentingEditor = true }
        .contextMenu {
            Button("Move Up") { onMoveUp() }
            Button("Move Down") { onMoveDown() }
            Divider()
            Button("Delete Phase", role: .destructive) { onDelete() }
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
                .font(Font.custom("BebasNeue-Regular", size: 22))
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

fileprivate enum NewBlockPhaseText {
    static func title(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:   return "Accumulation"
        case .intensification: return "Intensification"
        case .realization:    return "Peak"
        case .deload:         return "Deload"
        }
    }

    static func subtitle(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:   return "BUILD VOLUME"
        case .intensification: return "BUILD STRENGTH"
        case .realization:    return "SHARPEN OUTPUT"
        case .deload:         return "RECOVER"
        }
    }

    static func abbreviation(for kind: BlockPhaseKind) -> String {
        switch kind {
        case .accumulation:   return "ACCUM"
        case .intensification: return "INTEN"
        case .realization:    return "PEAK"
        case .deload:         return "DELOAD"
        }
    }

    static func volumeValue(_ multiplier: Double) -> String {
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

fileprivate struct NewBlockPhaseEditorSheet: View {
    @Bindable var draft: BlockPhaseDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
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

                ForEach(BlockPhaseKind.allCases, id: \.self) { kind in
                    let swatchColor = BlockPhaseColors.badgeColor(for: kind)

                    Button {
                        onSelect(kind)
                        dismiss()
                    } label: {
                        HStack(spacing: NewBlockScreenTokens.sectionGap) {
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

// 260528-vi2: linked routines band — borderless quiet row (no ink rules).
fileprivate struct NewBlockLinkedRoutinesBand: View {
    let count: Int

    var body: some View {
        HStack {
            Text("ROUTINES · \(count) LINKED")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)
            Spacer()
            Text("+ LINK")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)
        }
        .frame(height: 31)
        .background(NewBlockScreenTokens.paper)
    }
}

// Transient undo toast shown above the bottom action bar after context-menu delete.
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

// 260528-vi2: ghost CANCEL (left, intrinsic width) + filled rounded SAVE TEMPLATE (right, fills remaining).
// No heavy 3pt rule. Sits on paper with screen-margin insets.
fileprivate struct NewBlockBottomActionBar: View {
    let canCreate: Bool
    let isEditing: Bool
    let onCancel: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Ghost CANCEL button
            Button(action: onCancel) {
                Text("CANCEL")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.ctaTracking)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .frame(height: 52)
                    .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)

            // Filled primary button — fills remaining width
            Button(action: onPrimary) {
                HStack(spacing: 6) {
                    // Small filled square glyph (mockup detail)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .frame(width: 7, height: 7)
                        .foregroundStyle(.white)

                    Text(primaryTitle)
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.ctaTracking)
                        .foregroundStyle(canCreate ? .white : NewBlockScreenTokens.muted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canCreate ? NewBlockScreenTokens.ink : NewBlockScreenTokens.faint)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
        }
        .padding(.horizontal, NewBlockScreenTokens.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(NewBlockScreenTokens.paper)
        .frame(height: NewBlockScreenTokens.bottomActionHeight)
    }

    private var primaryTitle: String {
        if !canCreate {
            return "NAME FIRST ↑"
        }
        return isEditing ? "SAVE CHANGES ▸" : "SAVE TEMPLATE ▸"
    }
}

// MARK: - Shared Rules (kept for sheet internals)

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
