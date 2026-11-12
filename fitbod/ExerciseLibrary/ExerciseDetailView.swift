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
//      - tracking and family: copied as they are
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

    /// Draft for the Copy / Edit editor. Setting it presents the sheet,
    /// so the sheet always gets the draft it was opened with (a separate
    /// Bool flag let the first presentation render before the draft).
    @State private var editorDraft: CustomExerciseDraft? = nil

    /// The prescription setting being typed into, by its label.
    @FocusState private var focusedSetting: String?

    /// Unit label for the Prescription Settings fields. Per-exercise
    /// unitOverride takes precedence; falls back to global UserSettings;
    /// defaults to "lb" if no settings row exists yet.
    private var unitLabel: String { unit.rawValue }

    private var unit: WeightUnit {
        exercise.unitOverride ?? settingsList.first?.weightUnit ?? .lb
    }

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar.slots(
                left: .back,
                center: "Exercise",
                right: exercise.isCustom
                    ? .action("Edit") { openEditor(editing: true) }
                    : .action("Copy") { openEditor(editing: false) }
            )
            ScrollView {
                VStack(spacing: 0) {
                    heroBlock
                    BRUDivider(.ink)
                    recentPerformanceSection
                    muscleSection
                    instructionsSection
                    prescriptionSettingsSection
                    // Phase 5: SET-06 per-exercise plateau threshold override.
                    // A plateau is a stalled load, so only where load progresses.
                    if let settings = settingsList.first, exercise.tracking.progressesLoad {
                        plateauDetectionSection(settings: settings)
                    }
                    if !exercise.isCustom {
                        VStack(alignment: .leading, spacing: 8) {
                            BRUButton("Copy as Custom Exercise", kind: .ghost) {
                                openEditor(editing: false)
                            }
                            Text("Built-in exercises are read-only. A copy is yours to rename and re-target.")
                                .font(BRUFont.bodyDefault)
                                .foregroundStyle(Color.bruMuted)
                        }
                        .padding(16)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        // Number pads have no return key (T39).
        .keyboardDone()
        .sheet(item: $editorDraft) { draft in
            // Wrap the editor in its own NavigationStack so it owns its
            // toolbar (Save / Cancel). The editor dismisses itself on
            // save / discard / delete.
            NavigationStack {
                CustomExerciseEditor(draft: draft)
            }
        }
    }

    /// Copy (built-in) or edit (custom) through the custom-exercise editor.
    private func openEditor(editing: Bool) {
        let draft = makeDraft(from: exercise)
        if editing {
            draft.name = exercise.name
            draft.imageData = exercise.imageData
            draft.editingExisting = exercise
        }
        editorDraft = draft
    }

    // MARK: - Hero

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(BRUFont.condensedTitle)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            BRUFlowLayout(spacing: 6) {
                if let muscle = ExerciseRow.primaryMuscleLabel(exercise) {
                    BRUChip(muscle, color: .bruSignal, fill: true)
                }
                BRUChip(equipmentDisplay)
                if !exercise.isCardio {
                    BRUChip(mechanicDisplay)
                }
                if exercise.isCustom {
                    BRUChip("Custom", color: .bruSignal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: - Recent performance

    private var recentPerformanceSection: some View {
        VStack(spacing: 0) {
            RecentPerformanceList(exercise: exercise, unit: unit)
            NavigationLink {
                ExerciseHistoryView(exercise: exercise)
            } label: {
                linkRow("View all history")
            }
            .buttonStyle(.bruRow)
            // Phase 6 plan 06-05 — progress chart deep link, hidden while
            // nothing is logged (avoids an empty chart).
            ProgressEntryRow(exercise: exercise)
            BRUDivider(.ink)
        }
    }

    // MARK: - Instructions

    @ViewBuilder
    private var instructionsSection: some View {
        if !exercise.instructions.isEmpty {
            BRUSectionHead("How to")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(String(format: "%02d", i + 1))
                            .font(BRUFont.labelLarge)
                            .foregroundStyle(Color.bruMuted)
                            .frame(minWidth: 24, alignment: .leading)
                        Text(step)
                            .font(.bru(.text, size: 15))
                            .foregroundStyle(Color.bruInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(16)
            BRUDivider(.ink)
        }
    }

    // MARK: - Muscles section

    /// One bar per ExerciseMuscleStimulus join: primary tier first, then
    /// secondary; descending weight within each tier; alphabetical on ties.
    @ViewBuilder
    private var muscleSection: some View {
        let stimuli = exercise.muscleStimuli ?? []
        if !stimuli.isEmpty {
            BRUSectionHead("Muscles", right: "Stimulus")
            VStack(spacing: 10) {
                ForEach(stimuli.sorted(by: stimulusSort), id: \.id) { stim in
                    let percent = Int((stim.weight * 100).rounded())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stim.muscle?.displayName ?? "Unknown")
                                .font(BRUFont.bodyEmphasis)
                                .foregroundStyle(Color.bruInk)
                            if stim.role == "primary" {
                                Text("Primary")
                                    .font(BRUFont.labelMicro)
                                    .tracking(1.0)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.bruSignalText)
                            }
                            Spacer()
                            Text("\(percent)%")
                                .font(BRUFont.bodyEmphasis)
                                .monospacedDigit()
                                .foregroundStyle(Color.bruMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.bruFaint)
                                Rectangle()
                                    .fill(stim.role == "primary" ? Color.bruInk : Color.bruMuted)
                                    .frame(width: geo.size.width * min(1, max(0, stim.weight)))
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stim.muscle?.displayName ?? "Unknown"), \(stim.role), \(percent) percent")
                }
            }
            .padding(16)
            BRUDivider(.ink)
        }
    }

    private func linkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
            Spacer()
            Text("›")
                .font(BRUFont.displayMedium)
                .foregroundStyle(Color.bruMuted)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .top) { BRUDivider(.hair) }
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

    /// Per-exercise prescription overrides, written through @Bindable with
    /// no separate Save button. The increment and the bar feed a prescribed
    /// load, so they show only where load progresses. The unit shows where
    /// the exercise has one: a load, or a distance, whose miles go with lb
    /// and kilometers with kg (`SetText`). An exercise with neither, such as
    /// a plank or a stair climber, has no section.
    @ViewBuilder
    private var prescriptionSettingsSection: some View {
        @Bindable var ex = exercise
        let progresses = exercise.tracking.progressesLoad
        let measure = unitMeasure

        if progresses || measure != nil {
            BRUSectionHead(progresses ? "PRESCRIPTION SETTINGS" : "UNIT")
            VStack(alignment: .leading, spacing: 18) {
                if progresses {
                    settingField(
                        label: "SMALLEST INCREMENT",
                        placeholder: "e.g. 2.5",
                        value: $ex.smallestIncrement,
                        footer: "Weight advances by this amount each progression step."
                    )
                    settingField(
                        label: "BAR WEIGHT OVERRIDE",
                        placeholder: "Default",
                        value: $ex.barWeightOverride,
                        footer: "Use for specialty bars (safety squat, Swiss bar, women's bar)."
                    )
                }
                if let measure {
                    let isDistance = measure == "Distance"
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(measure) unit")
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                        HStack(spacing: 6) {
                            unitChip("System default", measure: measure, selected: ex.unitOverride == nil) {
                                ex.unitOverride = nil
                            }
                            ForEach([WeightUnit.kg, .lb], id: \.self) { choice in
                                unitChip(
                                    isDistance ? SetText.distanceUnit(choice) : choice.rawValue,
                                    measure: measure, selected: ex.unitOverride == choice
                                ) { ex.unitOverride = choice }
                            }
                        }
                        Text(isDistance
                             ? "Overrides the global unit for this exercise only. Distance is stored in meters."
                             : "Overrides the global unit for this exercise only. History stored in canonical unit.")
                            .font(BRUFont.bodyDefault)
                            .foregroundStyle(Color.bruMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            BRUDivider(.ink)
        }
    }

    /// What the exercise's unit measures, or nil when its sets record a
    /// time alone or a machine level or stair speed.
    private var unitMeasure: String? {
        switch exercise.tracking {
        case .weightReps, .reps, .assistedReps: "Weight"
        case .duration: exercise.timedValues.contains(.weight) ? "Weight" : nil
        case .durationDistance: "Distance"
        case .durationSpeedIncline: "Speed"
        case .durationLevel, .durationStepSpeed: nil
        }
    }

    private func settingField(
        label: String,
        placeholder: String,
        value: Binding<Double?>,
        footer: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(label)
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
                TextField(placeholder, value: value, format: .number)
                    .font(BRUFont.bodyEmphasis)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedSetting, equals: label)
                    // A number typed into the field replaces the one it
                    // shows (T39).
                    .selectsAllOnFocus(focusedSetting == label)
                    .frame(maxWidth: 120, minHeight: 44)
                    .padding(.horizontal, 8)
                    .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: 1.5))
                    .accessibilityLabel(label.capitalized)
                Text(unitLabel)
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            // The scroll view leaves a focused field behind the keyboard,
            // so the row scrolls clear of it and its DONE (T39).
            .revealsAboveKeyboard(focusedSetting == label)
            Text(footer)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func unitChip(
        _ title: String, measure: String, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            BRUChip(title, fill: selected)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(measure) unit: \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Display strings

    private var equipmentDisplay: String { exercise.equipment.displayName }

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
        draft.tracking = source.trackingRaw.flatMap(Tracking.init)
        // A copy joins its source's family under its own name, so it never
        // shows the source's variant label.
        draft.familyName = source.familyName
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
    // Reskinned in plan 05.1-08 — BRUSectionHead header + BRUButton ghost +
    // BRUFont labels/footers. ZERO banned tokens within this section boundary.

    /// SET-06 — per-exercise plateau threshold override editor.
    /// Toggle "Override global settings" seeds both override fields
    /// with the current global defaults when turned ON; when OFF both
    /// fields are nilled and the global defaults are used.
    @ViewBuilder
    private func plateauDetectionSection(settings: UserSettings) -> some View {
        @Bindable var ex = exercise

        VStack(alignment: .leading, spacing: 0) {
            BRUSectionHead(
                "Plateau Detection",
                right: ex.plateauWindowOverride != nil ? "Custom" : "Using defaults"
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Override global settings", isOn: Binding(
                        get: { ex.plateauWindowOverride != nil },
                        set: { newValue in
                            if newValue {
                                ex.plateauWindowOverride = settings.plateauWindowSessions
                                ex.plateauToleranceOverride = settings.plateauTolerance
                            } else {
                                ex.plateauWindowOverride = nil
                                ex.plateauToleranceOverride = nil
                            }
                        }
                    ))
                    .toggleStyle(.bru)

                if let windowOverride = ex.plateauWindowOverride,
                   let toleranceOverride = ex.plateauToleranceOverride {
                    BRUStepper(
                        "Window",
                        value: Binding(
                            get: { windowOverride },
                            set: { ex.plateauWindowOverride = $0 }
                        ),
                        in: 1...12,
                        step: 1
                    ) { BRUCountLabel.text($0, "session") }

                    BRUStepper(
                        "Tolerance",
                        value: Binding(
                            get: { toleranceOverride * 100 },
                            set: { ex.plateauToleranceOverride = $0 / 100 }
                        ),
                        in: 0.5...10,
                        step: 0.5
                    ) { String(format: "%.1f%%", $0) }

                    BRUButton("Use global defaults", kind: .ghost) {
                        ex.plateauWindowOverride = nil
                        ex.plateauToleranceOverride = nil
                    }
                }

                Text("Global defaults: \(BRUCountLabel.text(settings.plateauWindowSessions, "session")), \(Int((settings.plateauTolerance * 100).rounded()))% tolerance.")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    @Query private var loggedExercises: [SessionExercise]

    init(exercise: Exercise) {
        self.exercise = exercise
        let targetID: UUID? = exercise.id
        // Single-level optional chain only; deeper chains crash #Predicate.
        _loggedExercises = Query(
            filter: #Predicate<SessionExercise> { $0.exercise?.id == targetID }
        )
    }

    private var hasLoggedSets: Bool {
        loggedExercises.contains { !($0.sets ?? []).isEmpty }
    }

    var body: some View {
        if hasLoggedSets {
            NavigationLink {
                ExerciseProgressView(exercise: exercise)
            } label: {
                HStack {
                    Text("View progress chart")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruInk)
                    Spacer()
                    Text("›")
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruMuted)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { BRUDivider(.hair) }
            }
            .buttonStyle(.bruRow)
        }
    }
}

// MARK: - Recent performance

/// The last five finished workouts that included this exercise: date,
/// best working set and working-set count. This is the "previous
/// performance" a lifter checks before choosing today's load.
struct RecentPerformanceList: View {
    let unit: WeightUnit
    /// Cardio logs bouts, not sets (RM-062).
    let isCardio: Bool
    @Query private var logged: [SessionExercise]

    init(exercise: Exercise, unit: WeightUnit) {
        self.unit = unit
        self.isCardio = exercise.isCardio
        let targetID: UUID? = exercise.id
        // Single-level optional chain only; deeper chains crash #Predicate.
        _logged = Query(filter: #Predicate<SessionExercise> { $0.exercise?.id == targetID })
    }

    struct Entry: Identifiable {
        let id: UUID
        let date: Date
        let best: SetEntry
        let workingSets: Int

        /// "3 working sets", or "1 bout" for cardio, which set counts
        /// leave out (RM-062).
        var countLabel: String {
            BRUCountLabel.text(workingSets, best.sessionExercise?.exercise?.isCardio == true ? "bout" : "working set")
        }
    }

    /// One entry per finished workout, newest first, at most five. An
    /// entry reads the working sets of every log of the exercise in its
    /// workout: in log order, then set order (`orderIndex` both times),
    /// whatever order SwiftData returns them in. `max(by:)` keeps the
    /// first of equal elements, so the earlier set wins a tie for the
    /// best set. The best set is the heaviest, then the one with the most
    /// reps, and among timed sets the longest.
    static func entries(from logged: [SessionExercise]) -> [Entry] {
        let finishedLogs = logged.compactMap { item -> (session: Session, log: SessionExercise)? in
            guard let session = item.session, session.completedAt != nil else { return nil }
            return (session, item)
        }
        return Dictionary(grouping: finishedLogs) { $0.session.id }
            .values
            .compactMap { pairs -> Entry? in
                guard let session = pairs.first?.session else { return nil }
                let working = pairs
                    .map(\.log)
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .flatMap { log in
                        (log.sets ?? [])
                            .filter { $0.isComplete && !$0.isWarmup }
                            .sorted { $0.orderIndex < $1.orderIndex }
                    }
                func rank(_ set: SetEntry) -> (Double, Int, Int) {
                    (set.weight, set.reps, set.isTimed ? set.durationSeconds ?? 0 : 0)
                }
                guard let best = working.max(by: { rank($0) < rank($1) }) else { return nil }
                return Entry(id: session.id, date: session.startedAt, best: best, workingSets: working.count)
            }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        let entries = Self.entries(from: logged)
        BRUSectionHead("Recent performance", right: entries.isEmpty ? nil : isCardio ? "Best bout" : "Best set")
        if entries.isEmpty {
            Text("Not logged yet. Your best \(isCardio ? "bout" : "set") from each workout will show here.")
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        } else {
            ForEach(entries) { entry in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Text(entry.countLabel)
                            .font(BRUFont.labelSmall)
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }
                    Spacer()
                    Text(entry.best.resultText(unit: unit))
                        .font(BRUFont.condensedLabel)
                        .foregroundStyle(Color.bruInk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                BRUDivider(.hair)
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
