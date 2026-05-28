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

    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot = ""
    @State private var saveError: String? = nil

    public init(draft: BlockDraft, editing: Block? = nil) {
        self.draft = draft
        self.editing = editing
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

                    ScrollView {
                        VStack(spacing: 0) {
                            NewBlockNameBand(draft: draft)

                            NewBlockMetricsBand(
                                draft: draft,
                                decrementWeeks: { adjustTotalWeeks(by: -1) },
                                incrementWeeks: { adjustTotalWeeks(by: 1) }
                            )

                            NewBlockPhasesHeader(
                                phaseCount: draft.phases.count,
                                addPhase: addDefaultPhase
                            )

                            NewBlockTimelinePreview(phases: draft.phases)

                            ForEach(Array(draft.phases.enumerated()), id: \.element.draftID) { index, phase in
                                NewBlockPhaseEditorRow(draft: phase, displayIndex: index + 1)
                            }

                            NewBlockAddPhaseSlot(
                                addPhase: addDefaultPhase,
                                addPreset: applyHypertrophyPreset
                            )

                            if draft.isValid {
                                NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)
                            }

                            if let saveError {
                                errorBand(saveError)
                            }
                        }
                        .padding(.bottom, NewBlockScreenTokens.scrollBottomInset)
                    }
                    .scrollIndicators(.hidden)
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
            if initialSnapshot.isEmpty {
                initialSnapshot = snapshotHash()
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
            draft.isActive = true
            try draft.save(into: ctx)
            dismiss()
        } catch {
            saveError = "Couldn't save block. Try again."
        }
    }

    private func applyHypertrophyPreset() {
        draft.name = "Hypertrophy Meso"
        draft.isActive = true
        draft.daysPerWeek = 4
    }

    private func addDefaultPhase() {
        let defaults = BlockPhaseDraft.defaultMultipliers(for: .accumulation)
        draft.phases.append(
            BlockPhaseDraft(
                kind: .accumulation,
                weeks: 1,
                volumeMultiplier: defaults.volume,
                intensityMultiplier: defaults.intensity
            )
        )
    }

    private func adjustTotalWeeks(by delta: Int) {
        guard delta != 0 else { return }
        if delta > 0 {
            draft.phases.first?.weeks += delta
            return
        }

        if let index = draft.phases.firstIndex(where: { $0.kind != .deload && $0.weeks > 1 }) {
            draft.phases[index].weeks += delta
        } else if let index = draft.phases.firstIndex(where: { $0.weeks > 1 }) {
            draft.phases[index].weeks += delta
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

    static let topBarRowHeight: CGFloat = 50
    static let nameBandHeight: CGFloat = 152
    static let metricsHeight: CGFloat = 74
    static let phasesHeaderHeight: CGFloat = 36
    static let previewHeight: CGFloat = 104
    static let phaseRowHeight: CGFloat = 108
    static let metricCellHeight: CGFloat = 36
    static let addPhaseSlotHeight: CGFloat = 70
    static let bottomActionHeight: CGFloat = 60
    static let bottomButtonHeight: CGFloat = 54
    static let scrollBottomInset: CGFloat = 12
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
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BLOCK NAME")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)
                .padding(.top, 16)

            ZStack(alignment: .leading) {
                TextField("", text: $draft.name)
                    .font(nameFont)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .tint(NewBlockScreenTokens.ink)
                    .frame(height: 46)
                    .opacity(draft.name.isEmpty ? 0.02 : 1)
                    .focused($isNameFocused)

                if draft.name.isEmpty {
                    HStack(alignment: .center, spacing: 5) {
                        Text("NAME YOUR BLOCK")
                            .font(NewBlockType.displayLarge)
                            .foregroundStyle(NewBlockScreenTokens.muted)
                            .lineLimit(1)
                        if isNameFocused {
                            Rectangle()
                                .fill(NewBlockScreenTokens.ink)
                                .frame(width: 2, height: 38)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .padding(.top, 2)
            .contentShape(Rectangle())
            .onTapGesture { isNameFocused = true }

            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                presetRows
                    .padding(.top, 10)
            } else {
                activeChips
                    .padding(.top, 10)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NewBlockScreenTokens.nameBandHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }

    private var nameFont: Font {
        draft.name.isEmpty ? NewBlockType.displayLarge : NewBlockType.display
    }

    private var presetRows: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                NewBlockPresetChip("HYPERTROPHY MESO") { applyName("Hypertrophy Meso") }
                NewBlockPresetChip("LINEAR STRENGTH") { applyName("Linear Strength") }
                NewBlockPresetChip("POWERBUILDING") { applyName("Powerbuilding") }
            }
            HStack(spacing: 5) {
                NewBlockPresetChip("OFF-SEASON") { applyName("Off-Season") }
                NewBlockPresetChip("PRE-MEET") { applyName("Pre-Meet") }
            }
        }
    }

    private var activeChips: some View {
        HStack(spacing: 6) {
            Text("WILL ACTIVATE ON SAVE")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(.white)
                .frame(height: 30)
                .padding(.horizontal, 11)
                .background(NewBlockScreenTokens.signal)

            Text("\(draft.daysPerWeek) DAYS / WK")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .frame(height: 30)
                .padding(.horizontal, 11)
                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
        }
    }

    private func applyName(_ name: String) {
        draft.name = name
        draft.isActive = true
    }
}

fileprivate struct NewBlockPresetChip: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NewBlockType.chip)
                .tracking(1.8)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 26)
                .padding(.horizontal, 9)
                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metrics

fileprivate struct NewBlockMetricsBand: View {
    @Bindable var draft: BlockDraft
    let decrementWeeks: () -> Void
    let incrementWeeks: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TOTAL WEEKS")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                HStack(alignment: .center, spacing: 0) {
                    Text("\(draft.totalWeeks)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                        .frame(width: 44, alignment: .leading)

                    Spacer(minLength: 4)

                    HStack(spacing: 6) {
                        NewBlockStepperButton(label: "−", action: decrementWeeks)
                        NewBlockStepperButton(label: "+", action: incrementWeeks)
                    }
                }
            }
            .padding(.leading, NewBlockScreenTokens.sidePadding)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(NewBlockScreenTokens.ink)
                .frame(width: NewBlockScreenTokens.rule)

            VStack(alignment: .leading, spacing: 6) {
                Text("DAYS PER WEEK")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)

                HStack(alignment: .center, spacing: 0) {
                    Text("\(draft.daysPerWeek)")
                        .font(NewBlockType.display)
                        .foregroundStyle(NewBlockScreenTokens.ink)
                    Spacer(minLength: 4)
                    Text("3–6")
                        .font(NewBlockType.label)
                        .tracking(0.6)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, NewBlockScreenTokens.sidePadding)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: NewBlockScreenTokens.metricsHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NewBlockScreenTokens.ink)
                .frame(height: NewBlockScreenTokens.heavyRule)
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

fileprivate struct NewBlockPhasesHeader: View {
    let phaseCount: Int
    let addPhase: () -> Void

    var body: some View {
        HStack {
            Text("PHASES · \(phaseCount)")
                .font(NewBlockType.chrome)
                .tracking(NewBlockScreenTokens.chipTracking)
                .foregroundStyle(NewBlockScreenTokens.ink)
            Spacer()
            Button(action: addPhase) {
                Text("+ ADD PHASE")
                    .font(NewBlockType.chrome)
                    .tracking(NewBlockScreenTokens.chipTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .frame(height: NewBlockScreenTokens.phasesHeaderHeight)
        .background(NewBlockScreenTokens.paper)
        .overlay(alignment: .bottom) {
            NewBlockInkRule()
        }
    }
}

fileprivate struct NewBlockTimelinePreview: View {
    let phases: [BlockPhaseDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW")
                .font(NewBlockType.label)
                .tracking(NewBlockScreenTokens.labelTracking)
                .foregroundStyle(NewBlockScreenTokens.muted)

            GeometryReader { geometry in
                let total = max(CGFloat(phases.reduce(0) { $0 + $1.weeks }), 1)
                HStack(spacing: 0) {
                    ForEach(phases, id: \.draftID) { phase in
                        NewBlockTimelineSegment(phase: phase)
                            .frame(width: geometry.size.width * CGFloat(phase.weeks) / total)
                    }
                }
                .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
            }
            .frame(height: 36)

            HStack {
                Text("W1")
                Spacer()
                Text("W\(max(phases.reduce(0) { $0 + $1.weeks }, 1))")
            }
            .font(NewBlockType.label)
            .tracking(0.4)
            .foregroundStyle(NewBlockScreenTokens.muted)
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
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

    var body: some View {
        ZStack(alignment: .leading) {
            segmentFill
            Text(NewBlockPhaseText.abbreviation(for: phase.kind))
                .font(NewBlockType.label)
                .tracking(1.2)
                .foregroundStyle(phase.kind == .accumulation ? .white : NewBlockScreenTokens.ink)
                .padding(.leading, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .clipped()
    }

    @ViewBuilder
    private var segmentFill: some View {
        switch phase.kind {
        case .accumulation:
            NewBlockScreenTokens.ink
        case .intensification:
            NewBlockScreenTokens.signal
        case .realization:
            NewBlockScreenTokens.ink.opacity(0.25)
        case .deload:
            NewBlockDeloadStripes()
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", displayIndex))
                    .font(NewBlockType.phaseIndex)
                    .foregroundStyle(NewBlockScreenTokens.ink)
                    .frame(width: 32, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(NewBlockPhaseText.title(for: draft.kind))
                            .font(NewBlockType.phaseTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(NewBlockScreenTokens.ink)

                        if draft.kind == .deload {
                            Text("DELOAD")
                                .font(NewBlockType.label)
                                .tracking(NewBlockScreenTokens.labelTracking)
                                .foregroundStyle(NewBlockScreenTokens.signal)
                                .frame(height: 22)
                                .padding(.horizontal, 10)
                                .overlay(Rectangle().stroke(NewBlockScreenTokens.signal, lineWidth: 1.5))
                        }
                    }

                    Text(NewBlockPhaseText.subtitle(for: draft.kind))
                        .font(NewBlockType.label)
                        .tracking(1.2)
                        .foregroundStyle(NewBlockScreenTokens.muted)
                }

                Spacer()

                Text("⋮⋮")
                    .font(.custom("Geist-Regular", size: 16))
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(width: 28, height: 32)
                    .accessibilityLabel("Reorder phase \(displayIndex): \(BlockPhaseColors.phaseLabel(draft.kind))")
            }

            HStack(spacing: 7) {
                NewBlockPhaseMetricCell(label: "WEEKS", value: "\(draft.weeks)")
                NewBlockPhaseMetricCell(label: "VOL", value: NewBlockPhaseText.volumeValue(draft.volumeMultiplier))
                NewBlockPhaseMetricCell(label: "INT", value: NewBlockPhaseText.intensityValue(draft.intensityMultiplier))
            }
        }
        .padding(.horizontal, NewBlockScreenTokens.sidePadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
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

fileprivate struct NewBlockPhaseMetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(NewBlockType.micro)
                .tracking(1.4)
                .foregroundStyle(NewBlockScreenTokens.muted)
                .padding(.top, 6)
            Text(value)
                .font(NewBlockType.number)
                .foregroundStyle(NewBlockScreenTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NewBlockScreenTokens.metricCellHeight)
        .overlay(Rectangle().stroke(NewBlockScreenTokens.ink, lineWidth: 1.5))
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
        if abs(multiplier - 1.0) < 0.001 {
            return "HOLD"
        }
        let percent = Int(((multiplier - 1.0) * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    static func intensityValue(_ multiplier: Double) -> String {
        "\(Int((multiplier * 100).rounded()))%"
    }
}

// MARK: - Add Phase and Linked Routines

fileprivate struct NewBlockAddPhaseSlot: View {
    let addPhase: () -> Void
    let addPreset: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: addPhase) {
                HStack(spacing: 14) {
                    Text("+")
                        .font(NewBlockType.phaseTitle)
                        .fontWeight(.bold)
                    Text("ADD PHASE")
                        .font(NewBlockType.chrome)
                        .tracking(NewBlockScreenTokens.chipTracking)
                }
                .foregroundStyle(NewBlockScreenTokens.ink)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: addPreset) {
                Text("↘ PRESETS")
                    .font(NewBlockType.label)
                    .tracking(NewBlockScreenTokens.labelTracking)
                    .foregroundStyle(NewBlockScreenTokens.muted)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .overlay(
            Rectangle()
                .stroke(
                    NewBlockScreenTokens.ink,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 4])
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: NewBlockScreenTokens.addPhaseSlotHeight)
        .background(NewBlockScreenTokens.paper)
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
                        .tracking(2.8)
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
                        .tracking(2.8)
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
        return isEditing ? "SAVE CHANGES ▸" : "CREATE + ACTIVATE ▸"
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
