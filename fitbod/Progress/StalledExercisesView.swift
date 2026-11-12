//
//  StalledExercisesView.swift
//  fitbod
//
//  RM-019: the approved stalls mock-up (docs/design-map/mockups/
//  stalled-exercises.html), opened from Progress → Stalled. It lists, by
//  intent, each stall the workout's exercise card would show: the flat
//  workouts, the newest top set and the card's suggestion. A row opens the
//  exercise's chart, which marks the stall.
//
//  The suggestion is advice only and never changes a workout or a routine.
//  ADD VOLUME opens muscle detail for the muscle the volume check read, TRY
//  VARIATION the similar exercises, CONSIDER DELOAD the fatigue signals, and
//  DROP INTENSITY says how to apply it, since only a workout's sets can be
//  lightened.
//

import SwiftData
import SwiftUI

struct StalledExercisesView: View {
    let stalls: [ExerciseStall]
    @Binding var path: NavigationPath

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.weightUnit) private var defaultUnit
    @Query private var settingsList: [UserSettings]

    /// The stall whose DROP INTENSITY is being explained.
    @State private var explaining: ExerciseStall?
    /// The exercise whose similar exercises TRY VARIATION shows.
    @State private var variationSource: Exercise?
    /// "View all similar exercises in library" asks for the library, which
    /// opens once the variation sheet has gone.
    @State private var libraryAfterVariation = false
    @State private var browsingLibrary = false
    @State private var showingFatigueSignals = false

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: "Stalled"
            )
            ScrollView {
                LazyVStack(spacing: 0) {
                    band
                    ForEach(StalledExercises.sections(stalls), id: \.intent) { section in
                        BRUSectionHead(section.intent.rawValue.capitalized, right: "\(section.stalls.count)")
                        ForEach(Array(section.stalls.enumerated()), id: \.element.id) { index, stall in
                            if index > 0 { BRUDivider(.hair) }
                            row(stall)
                        }
                    }
                    BRUDivider(.ink)
                    plainNote("Set the window and tolerance for one exercise in its Library page.")
                        .padding(.horizontal, BRUMetrics.Spacing.gutter)
                        .padding(.vertical, BRUMetrics.Spacing.group)
                }
            }
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert(
            "Drop intensity",
            isPresented: Binding(get: { explaining != nil }, set: { if !$0 { explaining = nil } }),
            presenting: explaining
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { stall in
            Text(dropIntensityNote(stall))
        }
        .sheet(item: $variationSource, onDismiss: {
            guard libraryAfterVariation else { return }
            libraryAfterVariation = false
            browsingLibrary = true
        }) { exercise in
            TryVariationSheet(sourceExercise: exercise) { picked in
                if let picked {
                    path.append(ExerciseProgressRoute.progress(picked.id))
                } else {
                    libraryAfterVariation = true
                }
            }
        }
        .sheet(isPresented: $browsingLibrary) {
            // Browse mode has no close control; the sheet swipes away.
            ExerciseLibraryView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFatigueSignals) {
            if let settings = settingsList.first {
                DeloadSignalDetailSheet(report: DeloadAdvisor.signalReport(
                    weekStart: Date.now.mondayAtMidnightForToday(weekStartsMonday: settings.weekStartsMonday),
                    in: ctx,
                    settings: settings
                ))
            }
        }
    }

    // MARK: - Summary band

    /// The one signal element on the screen: STALLED and how many exercises,
    /// then the rule that finds them, with the user's default window.
    private var band: some View {
        let count = StalledExercises.exerciseCount(stalls)
        return VStack(alignment: .leading, spacing: BRUMetrics.Spacing.related) {
            HStack(spacing: BRUMetrics.Spacing.related) {
                if count > 0 {
                    Text("Stalled")
                        .font(BRUFont.labelSmall)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.bruPaper)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bruSignal)
                }
                Text(count > 0 ? BRUCountLabel.text(count, "exercise") : "No stalled exercises")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
            }
            .accessibilityElement(children: .combine)
            plainNote(ruleNote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .padding(.vertical, BRUMetrics.Spacing.group)
    }

    /// "…by default 4 workouts within 2%": the user's window and tolerance,
    /// which an exercise's own Library settings override.
    private var ruleNote: String {
        let settings = settingsList.first
        let window = BRUCountLabel.text(settings?.plateauWindowSessions ?? 4, "workout")
        let tolerance = (settings?.plateauTolerance ?? 0.02).formatted(.percent.precision(.fractionLength(0...1)))
        return "Top-set e1RM flat over each exercise's window of one intent: by default \(window) within \(tolerance)."
    }

    // MARK: - Row

    /// The exercise, its flat workouts and newest top set, opening its chart;
    /// then its suggestion, as on the workout's card.
    private func row(_ stall: ExerciseStall) -> some View {
        VStack(spacing: 0) {
            Button {
                path.append(ExerciseProgressRoute.progress(stall.exercise.id))
            } label: {
                HStack(spacing: BRUMetrics.Spacing.related) {
                    VStack(alignment: .leading, spacing: BRUMetrics.Spacing.tight) {
                        Text(stall.exercise.name)
                            .font(BRUFont.bodyEmphasis)
                            .foregroundStyle(Color.bruInk)
                        Text(stall.summary(unit: WeightUnit.effective(for: stall.exercise, default: defaultUnit)))
                            .font(BRUFont.labelSmall)
                            .foregroundStyle(Color.bruMuted)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text("›")
                        .font(BRUFont.bodyEmphasis)
                        .foregroundStyle(Color.bruMuted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, BRUMetrics.Spacing.gutter)
                .padding(.top, BRUMetrics.Spacing.group)
                .padding(.bottom, BRUMetrics.Spacing.tight)
                .frame(minHeight: BRUMetrics.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.bruRow)

            HStack {
                // The workout card's chip; only DROP INTENSITY does
                // something else here, so only its hint changes.
                SuggestedActionChip(action: stall.action) { act(on: stall) }
                    .accessibilityHint(stall.action == .dropIntensity
                                       ? "Says how to lighten its sets."
                                       : stall.action.accessibilityHint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BRUMetrics.Spacing.gutter)
            .padding(.bottom, BRUMetrics.Spacing.tight)
        }
    }

    /// Runs the suggestion's route. None of them writes anything.
    private func act(on stall: ExerciseStall) {
        switch stall.action {
        case .addVolume:
            // ADD VOLUME needs a primary muscle with a target, so there is one.
            if let slug = PlateauDetector.primaryMuscleSlug(of: stall.exercise) {
                path.append(MuscleSlugRoute.detail(slug))
            }
        case .dropIntensity:
            explaining = stall
        case .deload:
            showingFatigueSignals = true
        case .tryVariation:
            variationSource = stall.exercise
        }
    }

    /// Why DROP INTENSITY, and how to apply it: outside a workout there are
    /// no sets to lighten, and advice never changes a routine.
    private func dropIntensityNote(_ stall: ExerciseStall) -> String {
        let workouts = BRUCountLabel.text(stall.workouts.count, "\(stall.intent.rawValue) workout")
        return "RPE rose by a point or more at the same load over the last \(workouts). "
            + "Next time, try about 10% less weight. In a workout, DROP INTENSITY takes 10% off the sets "
            + "not yet done; from here it changes nothing."
    }

    private func plainNote(_ text: String) -> some View {
        Text(text)
            .font(BRUFont.labelSmall)
            .foregroundStyle(Color.bruMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
