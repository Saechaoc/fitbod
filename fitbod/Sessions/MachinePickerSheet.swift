// MachinePickerSheet.swift
// fitbod
//
// The machine picker (RM-066): which machine one exercise is done on in this
// workout. It offers None, the machines the exercise was logged on, known
// models for its family and other recent machines, and names a new one. The
// full maker list opens only from the new-machine form. A pick changes this
// workout's log only.

import SwiftUI
import SwiftData

struct MachinePickerSheet: View {
    let sessionExercise: SessionExercise
    let choices: SessionMachine.Choices

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .medium
    @State private var showingAllKnown = false
    @State private var naming = false
    @State private var maker: String?
    @State private var otherMaker = ""
    @State private var model = ""
    @State private var presentingMakerPicker = false
    /// A pick waiting on the finished-sets question.
    @State private var pending: Pick?
    @State private var changeFailed = false

    /// A machine by its names; both nil is no machine.
    struct Pick: Equatable {
        var manufacturer: String?
        var model: String?

        var isNone: Bool { manufacturer == nil && model == nil }
        var name: String { isNone ? "No machine" : MachineProfile.displayName(manufacturer: manufacturer, model: model) }
    }

    /// Known models listed before SHOW ALL.
    private static let knownLimit = 4
    /// None, each `MachineBrand`, then Other for a maker the list lacks.
    private static let makerOptions: [String?] =
        [nil] + MachineBrand.allCases.map { Optional($0.rawValue) } + ["Other"]

    var body: some View {
        VStack(spacing: 0) {
            if naming {
                BRUHeaderBar(
                    left: HeaderAction("‹ Back") { naming = false },
                    center: "New machine",
                    right: HeaderAction("Use", isSignal: true, isEnabled: newPick != nil) {
                        if let newPick { choose(newPick) }
                    }
                )
                ScrollView { newMachineForm }
            } else {
                BRUHeaderBar(left: HeaderAction("Cancel") { dismiss() }, center: "Machine")
                ScrollView { list }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "Which machine were your finished sets on?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { pick in
            Button(pick.name) { apply(pick, splitting: false) }
            Button(sessionExercise.machine?.displayName ?? "No machine") { apply(pick, splitting: true) }
            Button("Cancel", role: .cancel) {}
        } message: { pick in
            Text(pick.isNone ? "The sets still to do will have no machine." : "The sets still to do go on \(pick.name).")
        }
        .alert("Couldn't change the machine", isPresented: $changeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The workout is still saved as it was. Try again.")
        }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            row("None", maker: nil, selected: sessionExercise.machine == nil, identifier: "machine.none") {
                choose(Pick())
            }
            machines("This exercise", choices.usedForExercise, identifier: "machine.used")
            if !choices.suggested.isEmpty {
                let shown = showingAllKnown ? choices.suggested : Array(choices.suggested.prefix(Self.knownLimit))
                BRUSectionHead("Known machines")
                ForEach(Array(shown.enumerated()), id: \.element) { index, known in
                    if index > 0 { BRUDivider(.hair) }
                    row(known.model, maker: known.manufacturer, selected: false,
                        identifier: "machine.known.\(known.displayName)") {
                        choose(Pick(manufacturer: known.manufacturer, model: known.model))
                    }
                }
                if shown.count < choices.suggested.count {
                    BRUDivider(.hair)
                    textButton("Show all \(choices.suggested.count)", identifier: "machine.showAllKnown") {
                        showingAllKnown = true
                    }
                }
            }
            machines("Recent", choices.recent, identifier: "machine.recent")
            BRUDivider(.ink)
            textButton("+ New machine", identifier: "machine.new") {
                naming = true
                detent = .large
            }
            Text("This workout only. Next time, this exercise starts on the machine you used last.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .padding(.bottom, BRUMetrics.Spacing.gutter)
        }
    }

    @ViewBuilder
    private func machines(_ title: String, _ machines: [MachineProfile], identifier: String) -> some View {
        if !machines.isEmpty {
            BRUSectionHead(title)
            ForEach(Array(machines.enumerated()), id: \.element.id) { index, machine in
                if index > 0 { BRUDivider(.hair) }
                // A machine named by its model shows its maker below it.
                let title = machine.model ?? machine.manufacturer ?? ""
                row(title, maker: machine.model == nil ? nil : machine.manufacturer,
                    selected: machine.id == sessionExercise.machine?.id,
                    identifier: "\(identifier).\(machine.displayName)") {
                    choose(Pick(manufacturer: machine.manufacturer, model: machine.model))
                }
            }
        }
    }

    /// One choice: a BRU radio square, the name, and its maker below it.
    /// The list draws the rules between rows, so none doubles a section's.
    private func row(
        _ title: String, maker: String?, selected: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BRUMetrics.Spacing.group) {
                Rectangle()
                    .fill(selected ? Color.bruSignal : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(Rectangle().strokeBorder(selected ? Color.bruSignal : Color.bruInk, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if let maker {
                        Text(maker)
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.vertical, BRUMetrics.Spacing.related)
            .frame(minHeight: BRUMetrics.primaryActionHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(maker.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func textButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruSignalText)
                .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - New machine

    /// The new machine's names, or nil until one is typed.
    private var newPick: Pick? {
        let pick = Pick(
            manufacturer: maker == "Other" ? MachineProfile.cleaned(otherMaker) : maker,
            model: MachineProfile.cleaned(model)
        )
        return pick.isNone ? nil : pick
    }

    private var newMachineForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                presentingMakerPicker = true
            } label: {
                HStack(spacing: BRUMetrics.Spacing.group) {
                    VStack(alignment: .leading, spacing: 2) {
                        fieldLabel("Maker")
                        Text(maker ?? "None")
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                    }
                    Spacer(minLength: BRUMetrics.Spacing.related)
                    Text("›")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                }
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: BRUMetrics.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)
            .accessibilityLabel("Maker, \(maker ?? "None")")
            .accessibilityHint("Opens the list of makers")
            .accessibilityIdentifier("machine.maker")
            .sheet(isPresented: $presentingMakerPicker) {
                ChoicePickerSheet(
                    title: "Maker", options: Self.makerOptions, selection: $maker,
                    name: { $0 ?? "None" }, identifier: { "machine.maker.\($0 ?? "none")" }
                )
            }
            BRUDivider(.hair)
            if maker == "Other" {
                field("Maker name", text: $otherMaker, prompt: "e.g. Atlantis", identifier: "machine.otherMaker")
                BRUDivider(.hair)
            }
            field("Model or name", text: $model, prompt: "e.g. Super Hack Squat", identifier: "machine.model")
            BRUDivider(.hair)
            Text("Use the name on the machine, or any name you'll know it by.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(BRUMetrics.Spacing.gutter)
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldLabel(label)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(Color.bruMuted))
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .tint(Color.bruInk)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .frame(minHeight: BRUMetrics.touchTarget)
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .padding(.top, 10)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.bruMuted)
            .accessibilityHidden(true)
    }

    // MARK: - Choosing

    /// The current machine closes the sheet. Another one asks about the
    /// finished sets first, when there are any.
    private func choose(_ pick: Pick) {
        let current = sessionExercise.machine
        if current.map({ $0.matches(manufacturer: pick.manufacturer, model: pick.model) }) ?? pick.isNone {
            dismiss()
        } else if SessionMachine.hasFinishedWorkingSets(sessionExercise) {
            pending = pick
        } else {
            apply(pick, splitting: false)
        }
    }

    private func apply(_ pick: Pick, splitting: Bool) {
        if SessionMachine.change(
            sessionExercise, toManufacturer: pick.manufacturer, model: pick.model,
            splittingFinishedSets: splitting, context: context
        ) {
            dismiss()
        } else {
            changeFailed = true
        }
    }
}
