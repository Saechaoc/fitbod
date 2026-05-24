//
//  ExerciseDetailView.swift
//  fitbod
//
//  Wave-3 plan 03-03 — the read-only detail surface for any Exercise in
//  the library list. Pushed onto the Library tab's NavigationStack from
//  ExerciseLibraryView via `.navigationDestination(for: Exercise.self)`.
//
//  ## Composition (UI-SPEC § Exercise detail screen)
//
//  - Navigation title = exercise.name, inline display mode.
//  - List (.insetGrouped) with four read-only sections:
//      1. Instructions  — numbered list of `exercise.instructions`
//         (only rendered if non-empty).
//      2. Muscles       — one row per ExerciseMuscleStimulus join,
//         formatted "{Muscle name} · {weight as percent}". Sorted
//         primary first, then secondary; descending weight within each
//         tier; alphabetical by displayName on ties.
//      3. Equipment     — title-cased equipment value (Barbell / etc).
//      4. Mechanic      — "Compound" or "Isolation".
//  - Trailing button (only when `!exercise.isCustom`):
//      "Copy as Custom Exercise" — accent-foreground text button per
//      UI-SPEC § Color § Accent reserved for / item 4. Tapping hydrates
//      a `CustomExerciseDraft` from the source built-in exercise's
//      fields (name + " (Copy)" / equipment / mechanic / muscle
//      stimulus list with weights preserved) and presents
//      `CustomExerciseEditor` as a sheet wrapped in a NavigationStack.
//
//  ## Read-only affordance (UI-SPEC explicit)
//
//  Built-in exercises have NO "Edit" toolbar button and NO read-only
//  banner copy. UI-SPEC § Exercise detail screen line "Read-only banner
//  for built-in exercises (top of view): (none — absence of an edit
//  button IS the affordance; do not add explanatory text)" is followed
//  verbatim. The "Copy as Custom Exercise" CTA is the user's escape
//  hatch from the read-only world.
//
//  Custom exercises (isCustom == true) currently render the same four
//  sections without the "Copy as Custom" CTA. A direct "Edit" affordance
//  for custom exercises is deferred to Phase 1.x polish per the plan's
//  Out of Scope section.
//
//  ## Copy as Custom hydration (CONTEXT.md C-21 + C-22)
//
//  `makeDraft(from:)` builds a CustomExerciseDraft pre-populated with:
//      - name: source.name + " (Copy)"
//      - equipment: Equipment(rawValue: source.equipmentRaw) ?? .other
//      - mechanic: Mechanic(rawValue: source.mechanicRaw) ?? .compound
//      - muscles: one MuscleAssignment per source stimulus row,
//        preserving role + weight. Slug is taken from the stimulus's
//        muscle relationship (skipped if the relationship is missing
//        defensively — same resilience pattern as the importer).
//
//  Image data is intentionally NOT copied (C-22): built-in entries only
//  have unbundled `imagePaths` references with no `imageData` payload.
//  The user can attach a fresh image in the editor.
//
//  The hydrated draft has `editingExisting = nil`, so the editor's Save
//  handler calls `materialize(into:)` (insert NEW Exercise) rather than
//  `updateExisting(in:)` — meaning the source built-in is never
//  mutated. The user gets a new editable custom exercise; the built-in
//  remains pristine. (PITFALLS — never mutate templates from instance
//  flows.)
//
//  ## Why List (.insetGrouped) instead of Form
//
//  UI-SPEC § "comprehensive but uncluttered" plus visual continuity
//  with ExerciseLibraryView (which also uses `.insetGrouped`). Form is
//  for editing surfaces (the CustomExerciseEditor uses it); the detail
//  view is purely read-only display, so List + sections is the right
//  iOS-native pattern.
//

import SwiftUI
import SwiftData

/// Read-only detail surface for an Exercise. Built-in entries surface
/// a "Copy as Custom Exercise" CTA that hydrates a CustomExerciseDraft
/// and presents the editor over the detail view.
struct ExerciseDetailView: View {
    let exercise: Exercise

    /// Global unit settings — used to derive the `unitLabel` suffix for
    /// the Prescription Settings section (smallest increment / bar weight
    /// override). Per-exercise unitOverride takes precedence for display.
    @Query private var settingsList: [UserSettings]

    /// Draft hydrated by the "Copy as Custom Exercise" action. Held as
    /// optional state because it's only constructed at the moment the
    /// CTA is tapped, and the sheet body needs the same instance across
    /// re-renders so SwiftUI's `@Bindable` storage in the editor stays
    /// stable for the lifetime of the presentation.
    @State private var draftFromCopy: CustomExerciseDraft? = nil

    /// Toggled true when the "Copy as Custom Exercise" CTA is tapped.
    /// The sheet body reads `draftFromCopy` and presents the editor
    /// when both are non-nil/true.
    @State private var presentingCustomEditor = false

    /// Unit label for the Prescription Settings fields. Per-exercise
    /// unitOverride takes precedence; falls back to global UserSettings;
    /// defaults to "lb" if no settings row exists yet.
    private var unitLabel: String {
        let effective = exercise.unitOverride ?? settingsList.first?.weightUnit ?? .lb
        return effective.rawValue
    }

    var body: some View {
        List {
            if !exercise.instructions.isEmpty {
                Section("Instructions") {
                    // Numbered list — render "{index}. {step}" rows.
                    // Using `Array(enumerated())` so each step can be
                    // identified by its position (instructions are not
                    // independently Identifiable strings).
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text(step)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            muscleSection

            Section("Equipment") {
                Text(equipmentDisplay)
                    .font(.body)
            }

            Section("Mechanic") {
                Text(mechanicDisplay)
                    .font(.body)
            }

            // MARK: - Prescription Settings (plan 03-07 Task 3)
            //
            // Three editable fields for per-exercise prescription overrides.
            // Present for both built-in and custom exercises — the model
            // allows mutation of smallestIncrement / barWeightOverride /
            // unitOverride on any Exercise row. @Bindable projects the
            // Exercise @Model for write-through to SwiftData.

            prescriptionSettingsSection

            if !exercise.isCustom {
                Section {
                    Button {
                        // Hydrate a fresh draft from the source built-in
                        // exercise's fields. The draft is a separate
                        // CustomExerciseDraft — the source Exercise is
                        // never mutated (PITFALLS — read-only must mean
                        // read-only for built-in entries).
                        draftFromCopy = makeDraft(from: exercise)
                        presentingCustomEditor = true
                    } label: {
                        Text("Copy as Custom Exercise")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            // Phase 2 Wave 5 plan 05-01 — entry point to the per-exercise
            // history view (SESS-10 / ROUTINE-08). The detail view is the
            // Library tab's canonical landing surface for an Exercise, so
            // surfacing "View All History" here matches UI-SPEC §
            // "Exercise history view with intent split — Entry point" —
            // the user reaches the per-exercise history list from the
            // Library tab's NavigationStack, not from the session logger
            // (entering it mid-session would break logger focus per the
            // plan's anti-patterns list).
            Section("History") {
                NavigationLink {
                    ExerciseHistoryView(exercise: exercise)
                } label: {
                    HStack {
                        Text("View All History")
                        Spacer()
                    }
                }
                // Phase 6 plan 06-05 (PROG-01 / CONTEXT D-02) — deep-link
                // to the per-exercise progress chart. Hidden via the inner
                // ProgressEntryRow when SetEntry count == 0 to avoid a
                // useless empty-chart navigation.
                ProgressEntryRow(exercise: exercise)
            }

            // Phase 5 — SET-06 per-exercise plateau threshold override.
            if let settings = settingsList.first {
                plateauDetectionSection(settings: settings)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentingCustomEditor) {
            // Wrap the editor in its own NavigationStack so it owns its
            // toolbar (Save / Cancel) and navigation title. The editor
            // dismisses via `@Environment(\.dismiss)` on save/discard.
            if let draft = draftFromCopy {
                NavigationStack {
                    CustomExerciseEditor(draft: draft)
                }
            }
        }
    }

    // MARK: - Muscles section

    /// Renders one row per ExerciseMuscleStimulus join — primary tier
    /// first, then secondary; descending weight within each tier;
    /// alphabetical by displayName on weight ties.
    @ViewBuilder
    private var muscleSection: some View {
        let stimuli = exercise.muscleStimuli ?? []
        if !stimuli.isEmpty {
            Section("Muscles") {
                ForEach(stimuli.sorted(by: stimulusSort), id: \.id) { stim in
                    HStack {
                        Text(stim.muscle?.displayName ?? "Unknown")
                            .font(.body)
                        Spacer()
                        // Render as integer percent — UI-SPEC §
                        // Copywriting Contract "Muscle row label
                        // format: '{Muscle name} · {weight as percent}'
                        // — e.g. 'Chest · 100%', 'Triceps · 50%'".
                        // The middle-dot separator is provided by the
                        // HStack + Spacer; the row presents as
                        // "Chest                 100%" but VoiceOver
                        // reads them adjacent so the spec is honored.
                        Text("\(Int((stim.weight * 100).rounded()))%")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    /// Primary (`role == "primary"`) first, then secondary; within each
    /// tier, descending weight then alphabetical by display name.
    ///
    /// Comparator returns `true` when `a` should sort BEFORE `b`. The
    /// role check uses `a.role == "primary"` directly because the
    /// stimulus's `role` is stored as a raw String; an `a.role <
    /// b.role` lexicographic comparison would put "primary" AFTER
    /// "secondary" alphabetically, which is the wrong order.
    private func stimulusSort(_ a: ExerciseMuscleStimulus, _ b: ExerciseMuscleStimulus) -> Bool {
        if a.role != b.role { return a.role == "primary" }
        if a.weight != b.weight { return a.weight > b.weight }
        return (a.muscle?.displayName ?? "") < (b.muscle?.displayName ?? "")
    }

    // MARK: - Prescription Settings section (plan 03-07 / UI-SPEC § Per-exercise fields)
    // Reskinned in plan 03.2-08 — BRUSectionHead header + BRUFont labels/footers +
    // 3-BRUChip Button row replacing the Picker for unit override.

    /// Three editable sections for per-exercise prescription overrides
    /// (UI-SPEC § Per-exercise fields in ExerciseDetailView verbatim).
    /// @Bindable write-through to SwiftData — no separate Save button.
    @ViewBuilder
    private var prescriptionSettingsSection: some View {
        @Bindable var ex = exercise

        // Section 1: Smallest increment
        // Header: BRUSectionHead "PRESCRIPTION SETTINGS" per UI-SPEC line 308.
        // Label: BRUFont.labelSmall UPPERCASE 1.2 tracking bruMuted per line 309.
        // Footer: BRUFont.bodyDefault bruMuted per line 312.
        Section {
            HStack(spacing: 4) {
                Text("SMALLEST INCREMENT")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
                TextField(
                    "e.g. 2.5",
                    value: $ex.smallestIncrement,
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                Text(unitLabel)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
        } header: {
            BRUSectionHead("PRESCRIPTION SETTINGS")
        } footer: {
            Text("Weight advances by this amount each progression step.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }

        // Section 2: Bar weight override
        // No section header (continuation). Label + footer per UI-SPEC lines 313–315.
        Section {
            HStack(spacing: 4) {
                Text("BAR WEIGHT OVERRIDE")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
                TextField(
                    "Leave blank to use equipment default",
                    value: $ex.barWeightOverride,
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                Text(unitLabel)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
        } footer: {
            Text("Use for specialty bars (safety squat, Swiss bar, women's bar).")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }

        // Section 3: Weight unit override
        // Picker replaced by 3-BRUChip Button row per UI-SPEC line 317.
        // selected = ink fill, unselected = paper fill (fill: Bool param on BRUChip).
        // Accessibility: each Button gets .accessibilityLabel + .accessibilityAddTraits
        // per threat model T-03.2-16 (VoiceOver navigation correctness).
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("WEIGHT UNIT")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                HStack(spacing: 6) {
                    Button {
                        ex.unitOverride = nil
                    } label: {
                        BRUChip("System default", fill: ex.unitOverride == nil)
                    }
                    .accessibilityLabel("Weight unit: System default")
                    .accessibilityAddTraits(ex.unitOverride == nil ? .isSelected : [])

                    Button {
                        ex.unitOverride = .kg
                    } label: {
                        BRUChip("kg", fill: ex.unitOverride == .kg)
                    }
                    .accessibilityLabel("Weight unit: kg")
                    .accessibilityAddTraits(ex.unitOverride == .kg ? .isSelected : [])

                    Button {
                        ex.unitOverride = .lb
                    } label: {
                        BRUChip("lb", fill: ex.unitOverride == .lb)
                    }
                    .accessibilityLabel("Weight unit: lb")
                    .accessibilityAddTraits(ex.unitOverride == .lb ? .isSelected : [])
                }
            }
        } footer: {
            Text("Overrides the global unit for this exercise only. History stored in canonical unit.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
        }
    }

    // MARK: - Display strings

    /// Equipment value rendered title-cased per UI-SPEC ("Barbell",
    /// "Cable", "Weighted Bodyweight"). Splits underscored raws on
    /// `_` and capitalizes each component, matching plan 03-02 D-6
    /// convention. Single-word raws are a no-op for the split.
    private var equipmentDisplay: String {
        exercise.equipmentRaw
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    /// Mechanic value rendered "Compound" / "Isolation" per UI-SPEC.
    /// Raws are already single words, so `.capitalized` is sufficient.
    private var mechanicDisplay: String {
        exercise.mechanicRaw.capitalized
    }

    // MARK: - Copy as Custom hydration (CONTEXT.md C-21 + C-22)

    /// Build a `CustomExerciseDraft` from an existing built-in (or
    /// custom) `Exercise`. Used by the "Copy as Custom Exercise"
    /// action.
    ///
    /// The draft's `editingExisting` is left nil, so the editor's Save
    /// handler will invoke `materialize(into:)` (insert NEW Exercise)
    /// rather than `updateExisting(in:)`. The source `Exercise` is
    /// never mutated.
    ///
    /// Image data is intentionally not copied (C-22) — built-in entries
    /// have only `imagePaths` references to unbundled binaries; the
    /// user can attach a fresh image in the editor.
    private func makeDraft(from source: Exercise) -> CustomExerciseDraft {
        let draft = CustomExerciseDraft()
        draft.name = source.name + " (Copy)"
        draft.equipment = Equipment(rawValue: source.equipmentRaw) ?? .other
        draft.mechanic = Mechanic(rawValue: source.mechanicRaw) ?? .compound
        for stim in (source.muscleStimuli ?? []) {
            // Defensive: skip stimulus rows whose `muscle`
            // relationship somehow didn't resolve. Same resilience
            // pattern the importer uses for unknown slugs (plan 02-02
            // D-2).
            guard let slug = stim.muscle?.slug else { continue }
            let role: CustomExerciseDraft.MuscleAssignment.Role =
                stim.role == "primary" ? .primary : .secondary
            draft.muscles.append(
                .init(slug: slug, role: role, weight: stim.weight)
            )
        }
        // imageData intentionally not copied — see header comment C-22.
        return draft
    }

    // MARK: - Plateau Detection section (Phase 5 SET-06)

    /// SET-06 — per-exercise plateau threshold override editor.
    /// Toggle "Override global settings" seeds both override fields
    /// with the current global defaults when turned ON; when OFF both
    /// fields are nilled and the global defaults are used.
    @ViewBuilder
    private func plateauDetectionSection(settings: UserSettings) -> some View {
        @Bindable var ex = exercise

        Section {
            Toggle("Override global settings", isOn: Binding(
                get: { ex.plateauWindowOverride != nil },
                set: { isOn in
                    if isOn {
                        ex.plateauWindowOverride = settings.plateauWindowSessions
                        ex.plateauToleranceOverride = settings.plateauTolerance
                    } else {
                        ex.plateauWindowOverride = nil
                        ex.plateauToleranceOverride = nil
                    }
                }
            ))

            if let windowOverride = ex.plateauWindowOverride,
               let toleranceOverride = ex.plateauToleranceOverride {
                Stepper(
                    value: Binding(
                        get: { windowOverride },
                        set: { ex.plateauWindowOverride = $0 }
                    ),
                    in: 1...12,
                    step: 1
                ) {
                    LabeledContent("Window (sessions)") {
                        Text("\(windowOverride) sessions")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(
                    value: Binding(
                        get: { toleranceOverride * 100 },     // display as percent
                        set: { ex.plateauToleranceOverride = $0 / 100 }  // store as decimal
                    ),
                    in: 0.5...10,
                    step: 0.5
                ) {
                    LabeledContent("Tolerance (%)") {
                        Text(String(format: "%.1f%%", toleranceOverride * 100))
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Use global defaults") {
                    ex.plateauWindowOverride = nil
                    ex.plateauToleranceOverride = nil
                }
                .foregroundStyle(Color.accentColor)
            }
        } header: {
            HStack {
                Text("Plateau Detection")
                Spacer()
                Text(ex.plateauWindowOverride != nil ? "Custom" : "Using defaults")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        } footer: {
            Text("Global defaults: \(settings.plateauWindowSessions) sessions, \(Int((settings.plateauTolerance * 100).rounded()))% tolerance. Set in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Progress entry row (Phase 6 plan 06-05)

/// Conditional "View progress" navigation row — hidden when the
/// exercise has zero logged working SetEntries to avoid pushing
/// the user into an empty chart. Lives inside ExerciseDetailView's
/// History section.
private struct ProgressEntryRow: View {
    let exercise: Exercise
    @Query private var sets: [SetEntry]

    init(exercise: Exercise) {
        self.exercise = exercise
        let targetID = exercise.id
        _sets = Query(
            filter: #Predicate<SetEntry> { entry in
                entry.sessionExercise?.exercise?.id == targetID
            }
        )
    }

    var body: some View {
        if !sets.isEmpty {
            NavigationLink {
                ExerciseProgressView(exercise: exercise)
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.accentColor)
                    Text("View progress")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Built-in exercise") {
    NavigationStack {
        let container = PreviewModelContainer.make()
        let exercises = try! container.mainContext.fetch(FetchDescriptor<Exercise>())
        ExerciseDetailView(exercise: exercises.first!)
    }
    .modelContainer(PreviewModelContainer.make())
}

#Preview("Custom exercise (no Copy CTA)") {
    NavigationStack {
        let container = PreviewModelContainer.make()
        let ctx = container.mainContext
        let muscles = try! ctx.fetch(FetchDescriptor<MuscleGroup>())
        let chest = muscles.first(where: { $0.slug == "chest" })!
        let custom = Exercise.previewSample(
            name: "Cambered Bar Bench",
            equipment: .barbell,
            mechanic: .compound,
            primaryMuscleSlugs: ["chest"],
            isCustom: true
        )
        custom.instructions = [
            "Set up cambered bar on rack at upper-chest height.",
            "Unrack and lower bar to mid-sternum under control.",
            "Press to lockout, pause briefly, repeat for prescribed reps."
        ]
        ctx.insert(custom)
        ctx.insert(ExerciseMuscleStimulus(
            exercise: custom, muscle: chest, role: "primary", weight: 1.0
        ))
        try? ctx.save()
        return ExerciseDetailView(exercise: custom)
    }
    .modelContainer(PreviewModelContainer.make())
}
