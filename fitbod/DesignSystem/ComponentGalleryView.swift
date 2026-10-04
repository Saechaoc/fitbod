//
//  ComponentGalleryView.swift
//  fitbod
//
//  In-app gallery of the Chalkline design system (Settings → Component
//  gallery). Every token and component is rendered live with realistic
//  data so the system can be reviewed on device — in light/dark, at any
//  Dynamic Type size, with VoiceOver — not just in Xcode previews.
//
//  Mirrors the "Components" board of the Claude Design canvas; see
//  docs/design-system/components.md for the design ↔ code mapping.
//

import SwiftUI
import SwiftData

struct ComponentGalleryView: View {
    @State private var search = ""
    @State private var name = ""
    @State private var sets = 4
    @State private var rest = 180
    @State private var muscleSelected = true
    @State private var customOnly = false
    @State private var timer = RestTimerEngine(scheduler: NoopNotificationScheduler())
    @FocusState private var focus: SetField?
    @State private var demoSets: [SetEntry] = ComponentGalleryView.makeDemoSets()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Chalk.Space.xxl) {
                ChalkScreenHeader("Chalkline", overline: "Design system · v1", subtitle: "Warm chalk paper for reading, iron panels for live state, one signal orange for the next action.")

                colors
                typography
                spacingAndShape
                buttons
                selection
                inputs
                feedback
                data
                setRows
                timerSection
            }
            .padding(Chalk.Space.gutter)
        }
        .background {
            Color.chalkCanvas.ignoresSafeArea()
        }
        .navigationTitle("GALLERY")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !timer.isRunning {
                timer.start(seconds: 150, exerciseName: "Weighted Pull Ups")
            }
        }
    }

    // MARK: Colors

    private struct Swatch: Identifiable {
        let id: String
        let token: ChalkPalette.Token
        let use: String
    }

    private var swatches: [Swatch] {
        [
            Swatch(id: "canvas", token: ChalkPalette.canvas, use: "App background"),
            Swatch(id: "surface", token: ChalkPalette.surface, use: "Cards, rows"),
            Swatch(id: "sunken", token: ChalkPalette.sunken, use: "Inputs, idle chips"),
            Swatch(id: "complete", token: ChalkPalette.complete, use: "Completed set"),
            Swatch(id: "ink", token: ChalkPalette.ink, use: "Primary text"),
            Swatch(id: "ink-2", token: ChalkPalette.ink2, use: "Secondary text"),
            Swatch(id: "ink-3", token: ChalkPalette.ink3, use: "Captions"),
            Swatch(id: "divider", token: ChalkPalette.divider, use: "Hairlines"),
            Swatch(id: "panel", token: ChalkPalette.panel, use: "Live state"),
            Swatch(id: "accent", token: ChalkPalette.accent, use: "Primary action"),
            Swatch(id: "accent-ink", token: ChalkPalette.accentInk, use: "Accent text"),
            Swatch(id: "danger", token: ChalkPalette.danger, use: "Errors"),
        ]
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            ChalkSectionHeader("Color")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Chalk.Space.sm, alignment: .leading)], alignment: .leading, spacing: Chalk.Space.sm) {
                ForEach(swatches) { swatch in
                    HStack(spacing: Chalk.Space.sm) {
                        RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous)
                            .fill(swatch.token.color)
                            .overlay {
                                RoundedRectangle(cornerRadius: Chalk.Radius.sm, style: .continuous)
                                    .strokeBorder(Color.chalkDivider, lineWidth: Chalk.Line.hairline)
                            }
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(swatch.id).font(.chalkChip).textCase(.uppercase).foregroundStyle(.chalkInk)
                            Text(swatch.use).font(.caption).foregroundStyle(.chalkInk2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Type

    private var typography: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Type")
            Text("Push Day A").font(.chalkDisplay).textCase(.uppercase)
            Text("Routines").font(.chalkTitle).textCase(.uppercase)
            Text("Exercises").font(.chalkSubtitle).textCase(.uppercase)
            Text("Barbell Romanian Deadlift").font(.chalkHeadline)
            Text("Keep the bar over mid-foot and push the floor away.").font(.chalkBody)
            Text("Barbell · Hamstrings · Glutes").font(.chalkFootnote).foregroundStyle(.chalkInk2)
            Text("Set · Previous · lb · Reps").chalkLabelStyle()
            HStack(alignment: .firstTextBaseline, spacing: Chalk.Space.lg) {
                Text("185 × 5").font(.chalkMetric)
                Text("32:14").font(.chalkMetricLarge)
            }
        }
        .foregroundStyle(.chalkInk)
    }

    // MARK: Space + shape

    private var spacingAndShape: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            ChalkSectionHeader("Space · Shape")
            ForEach([("xs", Chalk.Space.xs), ("sm", Chalk.Space.sm), ("md", Chalk.Space.md), ("lg", Chalk.Space.lg), ("xl", Chalk.Space.xl), ("xxl", Chalk.Space.xxl)], id: \.0) { item in
                HStack(spacing: Chalk.Space.md) {
                    Text(item.0).font(.chalkChip).textCase(.uppercase).frame(width: 40, alignment: .leading)
                    Rectangle().fill(Color.chalkInk).frame(width: item.1, height: 10)
                    Text("\(Int(item.1)) pt").font(.caption).foregroundStyle(.chalkInk2)
                }
            }
            HStack(spacing: Chalk.Space.md) {
                ForEach([("sm", Chalk.Radius.sm), ("md", Chalk.Radius.md), ("lg", Chalk.Radius.lg), ("xl", Chalk.Radius.xl)], id: \.0) { item in
                    VStack(spacing: Chalk.Space.xs) {
                        RoundedRectangle(cornerRadius: item.1, style: .continuous)
                            .fill(Color.chalkSunken)
                            .overlay {
                                RoundedRectangle(cornerRadius: item.1, style: .continuous)
                                    .strokeBorder(Color.chalkInk, lineWidth: Chalk.Line.strong)
                            }
                            .frame(width: 56, height: 40)
                        Text("\(item.0) \(Int(item.1))").font(.caption).foregroundStyle(.chalkInk2)
                    }
                }
            }
        }
        .foregroundStyle(.chalkInk)
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Buttons")
            Button {} label: { Label("Start workout", systemImage: "play.fill") }
                .buttonStyle(.chalk(.primary, size: .large, fullWidth: true))
            Button {} label: { Label("Add set", systemImage: "plus") }
                .buttonStyle(.chalk(.secondary, fullWidth: true))
            HStack(spacing: Chalk.Space.sm) {
                Button("Done") {}.buttonStyle(.chalk(.inverse))
                Button("See all") {}.buttonStyle(.chalk(.ghost))
                Button("Discard") {}.buttonStyle(.chalk(.destructive))
            }
            Button("Disabled") {}
                .buttonStyle(.chalk(.primary, fullWidth: true))
                .disabled(true)
            HStack(spacing: Chalk.Space.sm) {
                ChalkIconButton("plus", accessibilityLabel: "Add", style: .outlined) {}
                ChalkIconButton("ellipsis", accessibilityLabel: "More") {}
            }
        }
    }

    // MARK: Selection

    private var selection: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Chips · Tags")
            HStack(spacing: Chalk.Space.sm) {
                ChalkChip("Chest", isSelected: muscleSelected, extraCount: 1, showsMenuIndicator: true) {
                    muscleSelected.toggle()
                }
                ChalkChip("Equipment", isSelected: false, showsMenuIndicator: true) {}
                ChalkChip("Custom", isSelected: customOnly) { customOnly.toggle() }
            }
            HStack(spacing: Chalk.Space.sm) {
                ChalkTag("Strength", style: .solid)
                ChalkTag("Hypertrophy")
                ChalkTag("Custom", style: .subtle)
                ChalkTag("Next", style: .accent)
            }
        }
    }

    // MARK: Inputs

    private var inputs: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            ChalkSectionHeader("Inputs")
            ChalkSearchField(text: $search, prompt: "Search 702 exercises")
            ChalkTextField("Routine name", text: $name, prompt: "e.g. Push Day A", error: name.isEmpty ? "Give this routine a name." : nil, isProminent: true)
            ChalkCard {
                VStack(spacing: 0) {
                    ChalkStepperRow("Sets", value: $sets, in: 1...10)
                    ChalkStepperRow("Rest", value: $rest, in: 0...600, step: 15) { ChalkFormat.duration(seconds: $0) }
                }
            }
        }
    }

    // MARK: Feedback

    private var feedback: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            ChalkSectionHeader("Messages · Empty state")
            ChalkInlineMessage("Fix 2 things to save: name the routine and add at least one exercise.", kind: .error)
            ChalkInlineMessage("Previous values come from your last strength session of this lift.")
            ChalkValidationText("Enter reps to complete set 2.")
            ChalkEmptyState(
                systemImage: "list.bullet.rectangle",
                title: "No routines yet",
                message: "Build a routine to start logging workouts.",
                primaryTitle: "New routine",
                primaryAction: {}
            )
        }
    }

    // MARK: Data

    private var data: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            ChalkSectionHeader("Panels · Metrics · Rows")
            ChalkPanel {
                VStack(alignment: .leading, spacing: Chalk.Space.md) {
                    Text("Push Day A").font(.chalkDisplay).textCase(.uppercase)
                    HStack(alignment: .top) {
                        ChalkMetric("Elapsed", value: "32:14", onPanel: true)
                        ChalkMetric("Sets", value: "7/14", onPanel: true)
                        ChalkMetric("Volume lb", value: "8,450", onPanel: true)
                    }
                    ChalkProgressBar(progress: 0.5)
                }
            }
            HStack(spacing: Chalk.Space.sm) {
                ChalkMetricTile("Best set", value: "205 × 3", caption: "+10 lb vs last")
                ChalkMetricTile("Est. 1RM", value: "225", caption: "lb")
            }
            ChalkCard(padding: Chalk.Space.md) {
                VStack(spacing: Chalk.Space.sm) {
                    ExerciseRow(exercise: .previewSample(name: "Barbell Bench Press - Medium Grip", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["chest"]))
                    ExerciseRow(exercise: .previewSample(name: "Cambered Bar Paused Bench Press (2-Board)", equipment: .barbell, mechanic: .compound, primaryMuscleSlugs: ["chest"], isCustom: true))
                }
            }
        }
    }

    // MARK: Set rows

    private var setRows: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Set entry")
            ChalkCard {
                VStack(spacing: Chalk.Space.xs) {
                    SetEntryRow(entry: demoSets[0], setLabel: "1", previous: .init(weight: 185, reps: 5, rpe: 7), targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: false, validation: .ok, identifierPrefix: "gallery.0", focus: $focus, onComplete: {}, onUncomplete: { demoSets[0].isComplete.toggle() }, onUsePrevious: {}, onEdited: {})
                        .background(Color.chalkComplete, in: RoundedRectangle(cornerRadius: Chalk.Radius.md, style: .continuous))
                    SetEntryRow(entry: demoSets[1], setLabel: "2", previous: .init(weight: 185, reps: 5, rpe: nil), targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: true, validation: .ok, identifierPrefix: "gallery.1", focus: $focus, onComplete: { demoSets[1].reps = max(demoSets[1].reps, 5); demoSets[1].isComplete = true }, onUncomplete: { demoSets[1].isComplete = false }, onUsePrevious: { demoSets[1].reps = 5 }, onEdited: {})
                    SetEntryRow(entry: demoSets[2], setLabel: "3", previous: .init(weight: 185, reps: 4, rpe: 9), targetRepsText: "4–6", unitLabel: "lb", allowsSignedWeight: false, isNext: false, validation: .missingReps, identifierPrefix: "gallery.2", focus: $focus, onComplete: {}, onUncomplete: {}, onUsePrevious: {}, onEdited: {})
                }
            }
        }
    }

    // MARK: Timer

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.sm) {
            ChalkSectionHeader("Rest timer")
            RestTimerDock(engine: timer)
            if !timer.isRunning {
                Button("Restart demo timer") {
                    timer.start(seconds: 150, exerciseName: "Weighted Pull Ups")
                }
                .buttonStyle(.chalk(.secondary, fullWidth: true))
            }
        }
    }

    static func makeDemoSets() -> [SetEntry] {
        let done = SetEntry()
        done.weight = 185
        done.reps = 5
        done.rpe = 8
        done.isComplete = true
        let next = SetEntry()
        next.weight = 185
        let missing = SetEntry()
        missing.weight = 185
        return [done, next, missing]
    }
}

#Preview("Component gallery") {
    NavigationStack {
        ComponentGalleryView()
    }
    .modelContainer(PreviewModelContainer.make())
}
