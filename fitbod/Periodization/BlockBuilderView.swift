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

    @State private var presentingTemplateSheet = false
    @State private var presentingDurationSheet = false
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

                            // 260610-g9d: phase header + cards live in their own child
                            // view so per-frame drag state doesn't invalidate this whole
                            // screen body (name band, metrics, Swift Charts card).
                            NewBlockPhaseListSection(
                                draft: draft,
                                onDelete: { beginPendingDelete($0) },
                                onAddPhase: { presentingAddPhaseTypePicker = true }
                            )

                            // Conditional linked-routines band
                            if draft.isValid {
                                NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)
                            }

                            // Error band
                            if let saveError {
                                errorBand(saveError)
                            }

                            // Bottom clearance: the safeAreaInset action bar already
                            // insets the scroll content — this is breathing room only.
                            Color.clear
                                .frame(height: NewBlockScreenTokens.scrollBottomClearance)
                        }
                        .padding(.horizontal, NewBlockScreenTokens.screenMargin)
                        .padding(.top, NewBlockScreenTokens.cardGap)
                    }
                    .scrollIndicators(.hidden)
                    .background(NewBlockScreenTokens.paper)
                }

                // Transient undo toast — visible above the action bar while
                // pendingDelete is non-nil; auto-dismisses when the 4s Task clears it.
                // The action bar lives in safeAreaInset, so the ZStack's bottom
                // safe-area edge is the bar's top — only a tight gap needed here.
                if pendingDelete != nil {
                    NewBlockUndoToast(onUndo: undoDelete)
                        .padding(.bottom, NewBlockScreenTokens.tightGap)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // BRUTabBar wiring pattern: bottom chrome attaches via safeAreaInset
            // (not a ZStack overlay) so its paper background reliably extends
            // through the home-indicator zone — a ZStack-overlay background's
            // ignoresSafeArea bleed does not engage, leaving a see-through strip
            // where scrolled phase cards show below CANCEL / SAVE TEMPLATE.
            .safeAreaInset(edge: .bottom, spacing: 0) {
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
        dismiss()
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

            // White card capsule "+ ADD PHASE" — two-tone coral/ink label (260610-dbz)
            Button(action: onAddPhase) {
                (
                    Text("+ ")
                        .foregroundStyle(NewBlockScreenTokens.signal)
                    + Text("ADD PHASE")
                        .foregroundStyle(NewBlockScreenTokens.ink)
                )
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(NewBlockScreenTokens.card, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(NewBlockScreenTokens.cardStroke,
                                lineWidth: NewBlockScreenTokens.cardStrokeWidth)
                )
                .shadow(color: NewBlockScreenTokens.cardShadow, radius: 6, x: 0, y: 2)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("+ ADD PHASE")
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

/// Swift Charts progression card — shows Volume (AreaMark, translucent gray) and
/// Intensity (bold LineMark + ring PointMark) with colored phase-band regions,
/// in-band phase labels per contiguous span, HIGH/LOW anchors, vertical RuleMark
/// at the selected week, and a value callout pill. Wrapped in a bruCard.
///
/// 260610-ey9: rebuilt from the dashed-line version to match reference.png.
fileprivate struct NewBlockProgressionChart: View {
    let phases: [BlockPhaseDraft]

    // Selected week for scrub / callout pill. Starts nil — selection chrome
    // (ring, RuleMark, callout pill) appears only after the user taps or scrubs.
    @State private var selectedWeek: Int? = nil

    // Measured callout pill width, used to clamp the pill inside the plot
    // area so edge-week selections (W1, last week) don't clip the pill.
    @State private var calloutWidth: CGFloat = 0

    /// Expand phases into per-week data points (Volume + Intensity series).
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

    /// Phase bands for colored background regions (start..end in 0-indexed cumulative weeks).
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

    /// Collapse adjacent same-kind phases into a single labeled span.
    /// 260610-ey9: phase labels emitted per contiguous span, not per phase.
    private var contiguousPhaseSpans: [(kind: BlockPhaseKind, start: Int, end: Int)] {
        var result: [(kind: BlockPhaseKind, start: Int, end: Int)] = []
        var offset = 0
        for phase in phases {
            let start = offset
            let end = offset + phase.weeks
            if let last = result.last, last.kind == phase.kind {
                result[result.count - 1] = (kind: last.kind, start: last.start, end: end)
            } else {
                result.append((kind: phase.kind, start: start, end: end))
            }
            offset = end
        }
        return result
    }

    private var totalWeeks: Int {
        phases.reduce(0) { $0 + $1.weeks }
    }

    /// X-axis week labels: every week when totalWeeks <= 8; strided for longer blocks.
    private var weekAxisValues: [Int] {
        guard totalWeeks >= 1 else { return [] }
        let step = totalWeeks <= 8 ? 1 : Int(ceil(Double(totalWeeks) / 8.0))
        return Array(stride(from: 1, through: totalWeeks, by: max(1, step)))
    }

    /// Y domain derived from all plotted data, padded for visual breathing room.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = max(10, (hi - lo) * 0.15)
        return (lo - pad)...(hi + pad)
    }

    /// Find the phase containing the given 1-indexed week.
    private func phase(forWeek week: Int) -> BlockPhaseDraft? {
        var offset = 0
        for phase in phases {
            let start = offset + 1
            let end = offset + phase.weeks
            if week >= start, week <= end { return phase }
            offset += phase.weeks
        }
        return nil
    }

    /// Build the callout pill text for the selected week.
    private func calloutText(for week: Int) -> String {
        guard let p = phase(forWeek: week) else { return "WK \(week)" }
        let intStr = NewBlockPhaseText.intensityValue(p.intensityMultiplier)
        let volStr = NewBlockPhaseText.volumeValue(p.volumeMultiplier)
        return "WK \(week) · INT \(intStr) · VOL \(volStr)"
    }

    // Chart layout constants.
    private enum ChartLayout {
        static let plotAreaHeight: CGFloat = 156
        static let emptyStateHeight: CGFloat = 156
        static let weekLabelSpacing: CGFloat = 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row + legend pill chips
            HStack(alignment: .center) {
                Text("PROGRESSION OVERVIEW")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                Spacer()

                // Legend pill chips — VOLUME: dashed line glyph; INTENSITY: line-dot-line glyph.
                // The series marker strings "Volume" / "Intensity" remain in the marks below.
                HStack(spacing: 8) {
                    // VOLUME chip — three short dashes
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(NewBlockScreenTokens.muted)
                                    .frame(width: 4, height: 1)
                            }
                        }
                        Text("VOLUME")
                            .font(NewBlockType.micro)
                            .tracking(1.2)
                            .foregroundStyle(NewBlockScreenTokens.muted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(NewBlockScreenTokens.card, in: Capsule())
                    .overlay(Capsule().stroke(NewBlockScreenTokens.hair, lineWidth: 0.75))

                    // INTENSITY chip — line-dot-line
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Rectangle()
                                .fill(NewBlockScreenTokens.ink)
                                .frame(width: 8, height: 1.5)
                            Circle()
                                .fill(NewBlockScreenTokens.ink)
                                .frame(width: 4, height: 4)
                            Rectangle()
                                .fill(NewBlockScreenTokens.ink)
                                .frame(width: 8, height: 1.5)
                        }
                        Text("INTENSITY")
                            .font(NewBlockType.micro)
                            .tracking(1.2)
                            .foregroundStyle(NewBlockScreenTokens.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(NewBlockScreenTokens.card, in: Capsule())
                    .overlay(Capsule().stroke(NewBlockScreenTokens.hair, lineWidth: 0.75))
                }
            }
            .padding(.bottom, 14)

            if phases.isEmpty {
                Text("Add phases to preview progression")
                    .font(NewBlockType.label)
                    .tracking(0.6)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: ChartLayout.emptyStateHeight)
            } else {
                Chart {
                    // ── Phase bands (drawn first so marks render on top) ──────────────
                    // Bands use x: weekStart+0.5 ... weekEnd+0.5 (cut between weeks).
                    // A thin 2pt accent rail caps each band's top edge in the phase color.
                    ForEach(phaseBands) { band in
                        // Tinted band fill (0.18 opacity)
                        RectangleMark(
                            xStart: .value("s", Double(band.start) + 0.5),
                            xEnd:   .value("e", Double(band.end) + 0.5),
                            yStart: .value("lo", yDomain.lowerBound),
                            yEnd:   .value("hi", yDomain.upperBound)
                        )
                        .foregroundStyle(
                            BlockPhaseColors.badgeColor(for: band.kind).opacity(0.18)
                        )

                        // 2pt top accent rail in the full phase color
                        let tinyEpsilon = (yDomain.upperBound - yDomain.lowerBound) * 0.015
                        RectangleMark(
                            xStart: .value("s", Double(band.start) + 0.5),
                            xEnd:   .value("e", Double(band.end) + 0.5),
                            yStart: .value("railLo", yDomain.upperBound - tinyEpsilon),
                            yEnd:   .value("railHi", yDomain.upperBound)
                        )
                        .foregroundStyle(BlockPhaseColors.badgeColor(for: band.kind))
                    }

                    // ── Volume AreaMark (translucent gray, anchored to chart floor) ──
                    // Drawn before intensity so intensity renders on top.
                    ForEach(points.filter { $0.series == "Volume" }) { pt in
                        AreaMark(
                            x: .value("Week", pt.week),
                            yStart: .value("floor", yDomain.lowerBound),
                            yEnd:   .value("Value", pt.value),
                            series: .value("Series", "Volume")
                        )
                        .foregroundStyle(NewBlockScreenTokens.muted.opacity(0.18))
                        .interpolationMethod(.linear)

                        // Thin dashed top edge following the volume line
                        LineMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value),
                            series: .value("Series", "Volume")
                        )
                        .foregroundStyle(NewBlockScreenTokens.muted.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }

                    // ── Intensity LineMark + PointMark (bold, rendered on top) ───────
                    ForEach(points.filter { $0.series == "Intensity" }) { pt in
                        LineMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value),
                            series: .value("Series", "Intensity")
                        )
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        // Solid filled dot at each week
                        PointMark(
                            x: .value("Week", pt.week),
                            y: .value("Value", pt.value)
                        )
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .symbolSize(44)

                        // Hollow ring around the selected week's point
                        if let sel = selectedWeek, pt.week == sel {
                            PointMark(
                                x: .value("Week", pt.week),
                                y: .value("Value", pt.value)
                            )
                            .symbol {
                                Circle()
                                    .stroke(NewBlockScreenTokens.ink, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                            .foregroundStyle(NewBlockScreenTokens.ink)
                        }
                    }

                    // ── Vertical dotted RuleMark at the selected week ─────────────────
                    if let sel = selectedWeek {
                        RuleMark(x: .value("sel", sel))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .foregroundStyle(NewBlockScreenTokens.ink.opacity(0.55))
                    }
                }
                .chartXScale(domain: 0.5 ... Double(totalWeeks) + 0.5)
                .chartXAxis {
                    AxisMarks(values: weekAxisValues) { value in
                        if let week = value.as(Int.self) {
                            AxisValueLabel {
                                Text("W\(week)")
                                    .font(NewBlockType.micro)
                                    .foregroundStyle(
                                        week == (selectedWeek ?? -1)
                                            ? NewBlockScreenTokens.ink
                                            : NewBlockScreenTokens.muted
                                    )
                                    .fontWeight(week == (selectedWeek ?? -1) ? .semibold : .regular)
                                    .padding(.top, ChartLayout.weekLabelSpacing)
                            }
                        }
                    }
                }
                .chartYAxis {
                    // Two hairline gridlines at 18% and 82% of the y range (HIGH and LOW).
                    let lo = yDomain.lowerBound
                    let hi = yDomain.upperBound
                    let range = hi - lo
                    AxisMarks(
                        position: .leading,
                        values: [lo + range * 0.18, lo + range * 0.82]
                    ) { _ in
                        AxisGridLine()
                            .foregroundStyle(NewBlockScreenTokens.hair)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXSelection(value: $selectedWeek)
                .sensoryFeedback(.selection, trigger: selectedWeek)
                .chartPlotStyle { plotArea in
                    plotArea.frame(height: ChartLayout.plotAreaHeight)
                }
                .accessibilityLabel(
                    "Progression overview, \(totalWeeks) weeks, \(contiguousPhaseSpans.count) phases. " +
                    "Volume and intensity by week. \(selectedWeek.map { "Selected week \($0)." } ?? "No week selected.")"
                )
                // ── Phase-label overlay (one label per contiguous span) ────────────────
                // 260610-ey9: phase labels emitted per contiguous span, not per phase.
                // Required: ForEach(phases, id: \.draftID) — used in timeline and phase-list rows.
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            // Per-span phase abbreviation centered inside the band
                            ForEach(Array(contiguousPhaseSpans.enumerated()), id: \.offset) { _, span in
                                let midWeek = Double(span.start + span.end) / 2.0 + 0.5
                                let xPos = proxy.position(forX: midWeek) ?? (geo.size.width / 2)
                                Text(NewBlockPhaseText.abbreviation(for: span.kind).uppercased())
                                    .font(NewBlockType.micro)
                                    .tracking(0.8)
                                    .foregroundStyle(BlockPhaseColors.phaseLabelInk(for: span.kind))
                                    .position(x: xPos, y: 12)
                            }

                            // HIGH / LOW y-anchor labels on the leading edge
                            let lo = yDomain.lowerBound
                            let hi = yDomain.upperBound
                            let range = hi - lo
                            let highY = proxy.position(forY: lo + range * 0.82) ?? 0
                            let lowY  = proxy.position(forY: lo + range * 0.18) ?? geo.size.height

                            Text("HIGH")
                                .font(NewBlockType.micro)
                                .tracking(0.6)
                                .foregroundStyle(NewBlockScreenTokens.muted)
                                .position(x: 18, y: highY)

                            Text("LOW")
                                .font(NewBlockType.micro)
                                .tracking(0.6)
                                .foregroundStyle(NewBlockScreenTokens.muted)
                                .position(x: 16, y: lowY)

                            // Value callout pill above the selected week
                            if let sel = selectedWeek,
                               let xPos = proxy.position(forX: Double(sel)) {
                                let intensityPt = points.first(where: { $0.week == sel && $0.series == "Intensity" })
                                let yPos: CGFloat = {
                                    if let pt = intensityPt,
                                       let y = proxy.position(forY: pt.value) {
                                        return max(22, y - 28)
                                    }
                                    return 22
                                }()
                                let halfPill = calloutWidth / 2
                                let clampedX = calloutWidth > 0
                                    ? min(max(xPos, halfPill + 4), geo.size.width - halfPill - 4)
                                    : xPos
                                Text(calloutText(for: sel))
                                    .font(NewBlockType.micro)
                                    .tracking(1.0)
                                    .foregroundStyle(NewBlockScreenTokens.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(NewBlockScreenTokens.paper)
                                            .overlay(
                                                Capsule()
                                                    .stroke(NewBlockScreenTokens.hair, lineWidth: 0.75)
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
                                    .fixedSize()
                                    .onGeometryChange(for: CGFloat.self) { proxy in
                                        proxy.size.width
                                    } action: { width in
                                        calloutWidth = width
                                    }
                                    .position(x: clampedX, y: yPos)
                            }
                        }
                    }
                }
            }
        }
        .padding(NewBlockScreenTokens.cardPadding)
        .bruCard()
    }
}

// MARK: - Phase List Section

// 260610-g9d: owns drag-to-reorder state so per-frame finger deltas invalidate only
// this subtree, not the whole BlockBuilderView body. The array is mutated once on
// drop (gap-based) — never mid-drag — so there is no index/offset double-counting.
// Per-row swipe-to-delete state lives inside NewBlockPhaseEditorRow; the delete/undo
// toast and the add-phase sheet stay with the parent via closures.
fileprivate struct NewBlockPhaseListSection: View {
    let draft: BlockDraft
    let onDelete: (BlockPhaseDraft) -> Void
    let onAddPhase: () -> Void

    @State private var draggingPhaseID: UUID? = nil
    @State private var dragTargetIndex: Int? = nil

    // One row pitch = card height + the 10pt VStack gap.
    private var phasePitch: CGFloat { NewBlockScreenTokens.phaseRowHeight + 10 }

    private static let reorderSpring: Animation = .spring(response: 0.28, dampingFraction: 0.86)

    var body: some View {
        // 260528-vi2 r2: header + cards in one tight 10pt VStack so the header sits
        // close above the first card.
        VStack(alignment: .leading, spacing: 10) {
            NewBlockPhasesHeader(
                phaseCount: draft.phases.count,
                onAddPhase: onAddPhase
            )

            // 260610-dbz: 10pt paper separation between phase cards.
            // 260610-g9d r2: the finger-tracking offset lives INSIDE the row
            // (@GestureState) so per-frame drag updates re-evaluate one card, not
            // this section. The row reports only boundary crossings; all reorder
            // animation here is explicit withAnimation — no .animation(value:)
            // modifiers to leak springs onto the held card.
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                    NewBlockPhaseEditorRow(
                        draft: phase,
                        displayIndex: index + 1,
                        rowIndex: index,
                        rowCount: draft.phases.count,
                        reorderPitch: phasePitch,
                        isDragging: draggingPhaseID == phase.draftID,
                        onDelete: { onDelete(phase) },
                        onMoveUp: { movePhase(phase, by: -1) },
                        onMoveDown: { movePhase(phase, by: 1) },
                        onReorderBegan: { beginReorder(phase, at: index) },
                        onReorderTarget: { target in retarget(target) },
                        onReorderEnded: { endReorder() }
                    )
                    // Siblings part to open the landing gap (spring via retarget's
                    // explicit withAnimation transaction).
                    .offset(y: gapOffset(rowIndex: index, phaseID: phase.draftID))
                    .scaleEffect(draggingPhaseID == phase.draftID ? 1.03 : 1.0)
                    .zIndex(draggingPhaseID == phase.draftID ? 1 : 0)
                }
            }
            // Haptic on lift only (nil → id); silent on drop (id → nil).
            .sensoryFeedback(trigger: draggingPhaseID) { _, newValue in
                newValue != nil ? .impact(weight: .medium) : nil
            }
        }
    }

    // Reorder helper — replaces the removed .onMove List affordance. VoiceOver
    // "Move Up" / "Move Down" accessibility actions call this.
    private func movePhase(_ phase: BlockPhaseDraft, by offset: Int) {
        guard let i = draft.phases.firstIndex(where: { $0.draftID == phase.draftID }) else { return }
        let j = i + offset
        guard draft.phases.indices.contains(j) else { return }
        draft.phases.swapAt(i, j)
    }

    private func beginReorder(_ phase: BlockPhaseDraft, at index: Int) {
        withAnimation(Self.reorderSpring) {
            draggingPhaseID = phase.draftID
            dragTargetIndex = index
        }
    }

    // Boundary crossings only — the row's hysteresis gate already deduplicates,
    // and the explicit transaction here is what springs the sibling gap shift.
    private func retarget(_ target: Int) {
        guard dragTargetIndex != target else { return }
        withAnimation(Self.reorderSpring) { dragTargetIndex = target }
    }

    // Commit the move exactly once, on drop. Resetting drag state inside the same
    // animation lets the lifted row settle into its new slot (the row's
    // @GestureState translation resets in a matching spring transaction).
    private func endReorder() {
        let activeID = draggingPhaseID
        let target = dragTargetIndex
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if let activeID,
               let from = draft.phases.firstIndex(where: { $0.draftID == activeID }),
               let target, target != from {
                draft.phases.move(fromOffsets: IndexSet(integer: from),
                                  toOffset: target > from ? target + 1 : target)
            }
            draggingPhaseID = nil
            dragTargetIndex = nil
        }
    }

    // Gap shift for rows between the origin and the drop slot; the lifted row's
    // finger tracking is applied separately (outside the spring modifiers).
    private func gapOffset(rowIndex: Int, phaseID: UUID) -> CGFloat {
        guard let activeID = draggingPhaseID,
              phaseID != activeID,
              let from = draft.phases.firstIndex(where: { $0.draftID == activeID }),
              let target = dragTargetIndex else { return 0 }
        if from < target, rowIndex > from, rowIndex <= target { return -phasePitch }
        if from > target, rowIndex >= target, rowIndex < from { return phasePitch }
        return 0
    }
}

// MARK: - Phase Rows

// 260528-vi2: compact rounded phase card. Direct-manipulation affordances:
// swipe-left reveals/commits Delete (custom gesture — .swipeActions is a no-op in a
// LazyVStack), and the trailing ⋮⋮ handle long-press-drags to reorder. No .contextMenu:
// it intercepts long-press and fights the drag; VoiceOver gets .accessibilityActions.
fileprivate struct NewBlockPhaseEditorRow: View {
    @Bindable var draft: BlockPhaseDraft
    let displayIndex: Int
    let rowIndex: Int
    let rowCount: Int
    let reorderPitch: CGFloat
    let isDragging: Bool
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onReorderBegan: () -> Void
    let onReorderTarget: (Int) -> Void
    let onReorderEnded: () -> Void

    @State private var presentingEditor = false

    // 260610-g9d r2: finger-tracking offset is row-local @GestureState so per-frame
    // drag updates invalidate only this card's body — never the parent section.
    // Auto-resets (with a spring matching endReorder's) on gesture end/cancel.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.85)))
    private var dragTranslation: CGFloat = 0

    // Last drop slot reported up — gates onReorderTarget to boundary crossings.
    @State private var liveTarget: Int? = nil

    // Swipe-to-delete (per-row). swipeOffset is the committed reveal; swipeDrag is the
    // live finger delta (auto-resets to 0 when the gesture ends or is interrupted).
    @State private var swipeOffset: CGFloat = 0
    @GestureState private var swipeDrag: CGFloat = 0
    @State private var cardWidth: CGFloat = 0

    private enum Swipe {
        static let activate: CGFloat = 12       // DragGesture minimumDistance
        static let revealWidth: CGFloat = 92    // resting open width = Delete button width
        static let commitFraction: CGFloat = 0.6 // full-swipe commit past 60% of card width
        static let dominance: CGFloat = 1.3     // |dx| must beat |dy|·dominance to claim swipe
    }

    private var revealed: Bool { swipeOffset < -1 }
    private var visibleOffset: CGFloat { min(0, swipeOffset + swipeDrag) }

    /// 1pt × 34pt hairline divider between stat columns (260610-dbz).
    private var phaseRowDivider: some View {
        Rectangle()
            .fill(NewBlockScreenTokens.hair)
            .frame(width: 1, height: 34)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground
            cardSurface
                .offset(x: visibleOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if revealed {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { swipeOffset = 0 }
                    } else {
                        presentingEditor = true
                    }
                }
                .simultaneousGesture(swipeGesture)
        }
        // Finger tracking 1:1. Gesture transactions carry no animation, and the
        // parent's reorder springs run in their own withAnimation transactions,
        // so nothing ever rubber-bands this offset mid-drag.
        .offset(y: dragTranslation)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: { cardWidth = $0 })
        .accessibilityLabel("Phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
        .accessibilityActions {
            Button("Move Up") { onMoveUp() }
            Button("Move Down") { onMoveDown() }
            Button("Delete Phase") { onDelete() }
        }
        // A row that gets lifted to reorder must not also be sitting half-open.
        .onChange(of: isDragging) { _, nowDragging in
            if nowDragging, swipeOffset != 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { swipeOffset = 0 }
            }
        }
        .sheet(isPresented: $presentingEditor) {
            NewBlockPhaseEditorSheet(draft: draft)
        }
    }

    // The warm card itself (rail + content), offset over the Delete affordance.
    private var cardSurface: some View {
        HStack(spacing: 0) {
            let chipFill  = BlockPhaseColors.badgeColor(for: draft.kind)
            let chipLabel = BlockPhaseColors.badgeLabelColor(for: draft.kind)

            // 260528-vi2 r2: colored left rail — anchors the phase color to the
            // card's left edge (clipped to the rounded corner by .bruCard).
            Rectangle()
                .fill(chipFill)
                .frame(width: 5)

            HStack(alignment: .center, spacing: 12) {
                // Semantic badge (phase color + Bebas index)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(NewBlockPhaseText.subtitle(for: draft.kind))
                        .font(NewBlockType.label)
                        .tracking(1.2)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                // Stat grid: hairline dividers before each column + chevron (260610-dbz)
                HStack(alignment: .top, spacing: 8) {
                    phaseRowDivider
                    NewBlockReadOnlyStatColumn(
                        label: "WEEKS",
                        value: "\(draft.weeks)"
                    )
                    phaseRowDivider
                    NewBlockReadOnlyStatColumn(
                        label: "VOL",
                        value: NewBlockPhaseText.volumeValue(draft.volumeMultiplier)
                    )
                    phaseRowDivider
                    NewBlockReadOnlyStatColumn(
                        label: "INT",
                        value: NewBlockPhaseText.intensityValue(draft.intensityMultiplier)
                    )
                }

                // Chevron affordance
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NewBlockScreenTokens.muted)

                // Drag handle — typographic ⋮⋮ (matches RoutineExerciseCard); long-press
                // then drag to reorder. Gesture is scoped to the handle so the card body
                // stays free for swipe-to-delete and tap-to-edit.
                Text("⋮⋮")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(width: 22, height: 44)
                    .contentShape(Rectangle())
                    .highPriorityGesture(reorderGesture)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 12)
            .padding(.trailing, NewBlockScreenTokens.cardPadding)
            .padding(.vertical, 12)
        }
        .bruCard(radius: NewBlockScreenTokens.phaseCardRadius)
    }

    // Trailing red Delete affordance revealed behind the card on swipe-left.
    private var deleteBackground: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: NewBlockScreenTokens.phaseCardRadius, style: .continuous)
                .fill(NewBlockScreenTokens.signal)
            Button(role: .destructive) {
                commitDelete()
            } label: {
                Text("Delete")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(.white)
                    .frame(width: Swipe.revealWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .opacity(visibleOffset < 0 ? 1 : 0)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: Swipe.activate)
            .updating($swipeDrag) { value, state, _ in
                // Horizontal-dominant only — vertical-leaning drags fall through to scroll.
                guard abs(value.translation.width) > abs(value.translation.height) * Swipe.dominance
                else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * Swipe.dominance
                else { return }
                let width = cardWidth > 0 ? cardWidth : 320
                let projected = value.predictedEndTranslation.width   // include flick velocity
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    if projected < -(width * Swipe.commitFraction) {
                        swipeOffset = -width
                    } else if value.translation.width < -Swipe.revealWidth * 0.5 {
                        swipeOffset = -Swipe.revealWidth
                    } else {
                        swipeOffset = 0
                    }
                }
                if swipeOffset <= -width { commitDelete() }
            }
    }

    // Long-press gate (so a scroll fling never arms it) then drag. The translation
    // stays row-local in @GestureState; only drop-slot boundary crossings are
    // reported up (with hysteresis so hovering at a boundary doesn't flicker the
    // sibling gap open/closed).
    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragTranslation) { value, state, _ in
                if case .second(true, let drag?) = value {
                    state = drag.translation.height
                }
            }
            .onChanged { value in
                switch value {
                case .first(true):
                    liveTarget = rowIndex
                    onReorderBegan()
                case .second(true, let drag?):
                    let raw = Double(rowIndex) + Double(drag.translation.height / reorderPitch)
                    let current = liveTarget ?? rowIndex
                    // Hysteresis: re-target only once the finger passes 0.55 of a
                    // pitch beyond the current slot's center.
                    if abs(raw - Double(current)) > 0.55 {
                        let next = min(max(Int(raw.rounded()), 0), rowCount - 1)
                        if next != current {
                            liveTarget = next
                            onReorderTarget(next)
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                liveTarget = nil
                onReorderEnded()
            }
    }

    // Route both full-swipe and the revealed Delete button through the existing
    // onDelete → beginPendingDelete → 4s undo toast. Reset so a recycled row is clean.
    private func commitDelete() {
        onDelete()
        swipeOffset = 0
    }
}

/// Center-aligned label-over-value stat column for the phase row.
/// 260610-dbz: center-aligned + narrowed to 38pt (was 40pt left-aligned in 260528-vi2 r2)
/// to compensate for the added hairline dividers and keep the title block from being squeezed.
fileprivate struct NewBlockReadOnlyStatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(NewBlockType.micro)
                .tracking(1.2)
                .foregroundStyle(NewBlockScreenTokens.muted)
                .multilineTextAlignment(.center)
            Text(value)
                .font(Font.custom("BebasNeue-Regular", size: 22))
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(width: 38, alignment: .center)
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
        case .accumulation:   return "Accum."
        case .intensification: return "Intens."
        case .realization:    return "Peak"
        case .deload:         return "Deload"
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
        // Paper must run through the bottom safe area — the ScrollView's content
        // scrolls under the home-indicator zone, and a background that stops at
        // the safe-area edge leaves a see-through strip below the bar. Sized
        // intrinsically (~70pt) — safeAreaInset placement needs no rigid frame.
        .background(NewBlockScreenTokens.paper.ignoresSafeArea(edges: .bottom))
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

// 7-week fixture for chart-proportion checks against final-design.png.
// (BlockPhaseKind has 4 cases; the mockup's separate "Realization" phase is
// covered by .realization, which renders as "Peak".)
@MainActor
private func sevenWeekPhases() -> [BlockPhaseDraft] {
    [
        BlockPhaseDraft(kind: .accumulation, weeks: 2, volumeMultiplier: 1.2, intensityMultiplier: 0.70),
        BlockPhaseDraft(kind: .intensification, weeks: 2, volumeMultiplier: 1.0, intensityMultiplier: 0.85),
        BlockPhaseDraft(kind: .deload, weeks: 1, volumeMultiplier: 0.5, intensityMultiplier: 0.60),
        BlockPhaseDraft(kind: .realization, weeks: 2, volumeMultiplier: 0.8, intensityMultiplier: 0.95),
    ]
}

#Preview("New Block — 7-week meso") {
    let draft = BlockDraft.newBlock()
    draft.name = "Hypertrophy Meso"
    draft.phases = sevenWeekPhases()
    return BlockBuilderView(draft: draft)
        .modelContainer(PreviewModelContainer.make(seedFixture: false))
}

#Preview("Progression chart — 7-week") {
    NewBlockProgressionChart(phases: sevenWeekPhases())
        .padding(20)
        .background(Color(red: 240 / 255, green: 237 / 255, blue: 229 / 255))
}
#endif
