//
//  ExerciseDetailView.swift
//  fitbod
//
//  Exercise detail (Chalkline redesign of plan 03-03):
//
//    1. Iron hero — full name, equipment / mechanic / level tags, CUSTOM
//       tag, and the stimulus weighting per muscle as bars (primary 100%,
//       assisting 50% by default).
//    2. YOUR HISTORY — last logged date, best set, estimated 1RM, and the
//       five most recent sessions with their top set; "See all" opens the
//       intent-split history list. Previous performance lives here.
//    3. HOW TO — numbered instructions from the catalog.
//    4. Prescription settings (collapsed) — smallest increment, bar weight
//       override, unit override (plan 03-07).
//    5. Built-in: "Copy as custom exercise". Custom: Edit in the toolbar
//       (rename, muscles, equipment, delete).
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @Query private var settingsList: [UserSettings]

    @State private var history: ExerciseHistorySummary?
    @State private var draftForEditor: CustomExerciseDraft?
    @State private var showingSettings = false
    @State private var pendingDelete: Exercise?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Chalk.Space.xl) {
                hero
                historySection
                if !exercise.instructions.isEmpty {
                    instructionsSection
                }
                settingsSection
                if !exercise.isCustom {
                    Button("Copy as custom exercise") {
                        draftForEditor = makeCopyDraft()
                    }
                    .buttonStyle(.chalk(.secondary, fullWidth: true))
                    .accessibilityIdentifier("exercise.copyAsCustom")
                }
            }
            .padding(.horizontal, Chalk.Space.gutter)
            .padding(.vertical, Chalk.Space.lg)
        }
        .background {
            Color.chalkCanvas.ignoresSafeArea()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if exercise.isCustom {
                    Button("Edit") {
                        draftForEditor = CustomExerciseDraft.editing(exercise)
                    }
                    .accessibilityIdentifier("exercise.edit")
                }
            }
        }
        .sheet(item: $draftForEditor, onDismiss: performPendingDelete) { draft in
            NavigationStack {
                CustomExerciseEditor(draft: draft, onDelete: { target in
                    pendingDelete = target
                })
            }
        }
        .task(id: exercise.id) {
            history = ExerciseHistorySummary.load(exerciseID: exercise.id, context: ctx)
        }
    }

    // MARK: Hero

    private var hero: some View {
        ChalkPanel {
            VStack(alignment: .leading, spacing: Chalk.Space.md) {
                Text(exercise.name)
                    .font(.chalkDisplay)
                    .textCase(.uppercase)
                    .foregroundStyle(.chalkOnPanel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("exercise.detail.title")
                HStack(spacing: Chalk.Space.xs) {
                    ChalkTag(ExerciseRow.equipmentName(exercise.equipmentRaw), style: .onPanel)
                    ChalkTag(exercise.mechanicRaw, style: .onPanel)
                    if let level = exercise.levelRaw {
                        ChalkTag(level, style: .onPanel)
                    }
                    if exercise.isCustom {
                        ChalkTag("Custom", style: .accent)
                    }
                }
                let stimuli = sortedStimuli
                if !stimuli.isEmpty {
                    VStack(alignment: .leading, spacing: Chalk.Space.sm) {
                        ForEach(stimuli, id: \.id) { stimulus in
                            HStack(spacing: Chalk.Space.md) {
                                Text(stimulus.muscle?.displayName ?? "Unknown")
                                    .font(.chalkCallout)
                                    .foregroundStyle(.chalkOnPanel)
                                    .frame(minWidth: 96, alignment: .leading)
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.chalkPanelRaised)
                                        Capsule()
                                            .fill(stimulus.role == "primary" ? Color.chalkOnPanel : Color.chalkOnPanel2)
                                            .frame(width: proxy.size.width * min(1, max(0, stimulus.weight)))
                                    }
                                }
                                .frame(height: 6)
                                Text("\(Int((stimulus.weight * 100).rounded()))%")
                                    .font(.chalkFootnote.monospacedDigit())
                                    .foregroundStyle(.chalkOnPanel2)
                                    .frame(minWidth: 40, alignment: .trailing)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("\(stimulus.muscle?.displayName ?? "Unknown"), \(stimulus.role), \(Int((stimulus.weight * 100).rounded())) percent"))
                        }
                    }
                }
            }
        }
    }

    private var sortedStimuli: [ExerciseMuscleStimulus] {
        (exercise.muscleStimuli ?? []).sorted { a, b in
            if a.role != b.role { return a.role == "primary" }
            if a.weight != b.weight { return a.weight > b.weight }
            return (a.muscle?.displayName ?? "") < (b.muscle?.displayName ?? "")
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Your history") {
                NavigationLink(value: AppRoute.exerciseHistory(exercise)) {
                    Text("See all")
                        .font(.chalkChip)
                        .textCase(.uppercase)
                        .foregroundStyle(.chalkAccentInk)
                        .frame(minHeight: Chalk.Size.minTouch)
                }
                .accessibilityIdentifier("exercise.history.seeAll")
            }
            if let history, !history.isEmpty {
                HStack(spacing: Chalk.Space.sm) {
                    ChalkMetricTile("Last", value: history.lastDate.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "—")
                    ChalkMetricTile("Best set", value: history.best.map { "\(ChalkFormat.weight($0.weight)) × \($0.reps)" } ?? "—")
                    ChalkMetricTile("Est. 1RM", value: history.bestEstimatedOneRepMax.map { ChalkFormat.weight($0.rounded()) } ?? "—", caption: unitLabel)
                }
                ChalkCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(history.entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Rectangle().fill(Color.chalkDivider).frame(height: Chalk.Line.hairline)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.md) {
                                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.chalkChip)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.chalkInk)
                                    .frame(minWidth: 96, alignment: .leading)
                                Text("\(entry.routineName.isEmpty ? "Workout" : entry.routineName) · \(entry.setCount) set\(entry.setCount == 1 ? "" : "s")")
                                    .font(.chalkFootnote)
                                    .foregroundStyle(.chalkInk2)
                                Spacer(minLength: Chalk.Space.sm)
                                Text("\(ChalkFormat.weight(entry.top.weight)) × \(entry.top.reps)")
                                    .font(.chalkMetric)
                                    .foregroundStyle(.chalkInk)
                            }
                            .padding(.horizontal, Chalk.Space.md)
                            .padding(.vertical, Chalk.Space.md)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            } else {
                Text("Not logged yet. Add it to a routine and log a workout — your sets, best lift and estimated 1RM will show here.")
                    .font(.chalkCallout)
                    .foregroundStyle(.chalkInk2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("exercise.history.empty")
            }
        }
    }

    // MARK: Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("How to")
            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.sm) {
                    Text("\(index + 1)")
                        .font(.chalkMetric)
                        .foregroundStyle(.chalkInk)
                        .frame(minWidth: 24, alignment: .leading)
                    Text(step)
                        .font(.chalkBody)
                        .foregroundStyle(.chalkInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Prescription settings (plan 03-07)

    private var unitLabel: String {
        (exercise.unitOverride ?? settingsList.first?.weightUnit ?? .lb).rawValue
    }

    private var settingsSection: some View {
        @Bindable var ex = exercise
        return DisclosureGroup(isExpanded: $showingSettings) {
            VStack(alignment: .leading, spacing: Chalk.Space.md) {
                settingField(
                    "Smallest increment",
                    footnote: "Weight advances by this amount each progression step.",
                    value: $ex.smallestIncrement,
                    prompt: "e.g. 2.5"
                )
                settingField(
                    "Bar weight override",
                    footnote: "For specialty bars (safety squat, Swiss bar, women's bar).",
                    value: $ex.barWeightOverride,
                    prompt: "Equipment default"
                )
                VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                    HStack {
                        Text("Weight unit").font(.chalkBody).foregroundStyle(.chalkInk)
                        Spacer()
                        Picker(
                            "Weight unit",
                            selection: Binding(
                                get: { ex.unitOverride },
                                set: { ex.unitOverride = $0 }
                            )
                        ) {
                            Text("Default").tag(Optional<WeightUnit>.none)
                            Text("kg").tag(Optional<WeightUnit>.some(.kg))
                            Text("lb").tag(Optional<WeightUnit>.some(.lb))
                        }
                        .pickerStyle(.menu)
                        .tint(Color.chalkAccentInk)
                    }
                    Text("Overrides the global unit for this exercise's display.")
                        .font(.chalkFootnote)
                        .foregroundStyle(.chalkInk2)
                }
            }
            .padding(.top, Chalk.Space.sm)
        } label: {
            Text("Prescription settings")
                .font(.chalkSubtitle)
                .textCase(.uppercase)
                .foregroundStyle(.chalkInk)
                .frame(minHeight: Chalk.Size.minTouch)
        }
        .tint(Color.chalkInk)
    }

    private func settingField(_ title: String, footnote: String, value: Binding<Double?>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
            HStack {
                Text(title).font(.chalkBody).foregroundStyle(.chalkInk)
                Spacer()
                TextField(title, value: value, format: .number, prompt: Text(prompt).foregroundStyle(Color.chalkInk3))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.chalkMetric)
                    .frame(maxWidth: 140)
                Text(unitLabel)
                    .font(.chalkFootnote)
                    .foregroundStyle(.chalkInk2)
            }
            .frame(minHeight: Chalk.Size.minTouch)
            Text(footnote)
                .font(.chalkFootnote)
                .foregroundStyle(.chalkInk2)
        }
    }

    // MARK: Editor

    /// Built-in → editable custom copy. Image data is not copied (C-22).
    private func makeCopyDraft() -> CustomExerciseDraft {
        let draft = CustomExerciseDraft()
        draft.name = exercise.name + " (Copy)"
        draft.equipment = Equipment(rawValue: exercise.equipmentRaw) ?? .other
        draft.mechanic = Mechanic(rawValue: exercise.mechanicRaw) ?? .compound
        for stimulus in exercise.muscleStimuli ?? [] {
            guard let slug = stimulus.muscle?.slug else { continue }
            let role: CustomExerciseDraft.MuscleAssignment.Role = stimulus.role == "primary" ? .primary : .secondary
            draft.muscles.append(.init(slug: slug, role: role, weight: stimulus.weight))
        }
        return draft
    }

    /// The editor asked to delete this exercise: leave the screen first,
    /// then delete, so nothing renders a deleted model.
    private func performPendingDelete() {
        guard let target = pendingDelete else { return }
        pendingDelete = nil
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            ExerciseStore.delete(target, context: ctx)
        }
    }
}
