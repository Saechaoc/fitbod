// LiftListSection.swift
// fitbod — Phase 2.1 Plan 04
//
// BRUSectionHead("Exercises · N", right: "View ›") + LazyVStack of LiftListRow.
// Reference: bru-screens/today.jsx lines 83-110
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
// NO .font(.body/.headline/.title*/.caption)

import SwiftUI
import SwiftData

// MARK: - LiftListSection

/// The Exercises head and the rows of today's session. The head counts the
/// exercises and its View › opens the session. With no exercises it renders
/// a minimal "Add an exercise to begin." placeholder (NOT the full
/// empty-state surface, which lives at TodayView).
public struct LiftListSection: View {

    // MARK: - Properties

    let routine: SessionTemplate
    /// The block's current phase; a deload cuts each row's working sets.
    let phase: BlockPhase?
    /// Rows shown before "Show all"; nil shows every row.
    var previewCount: Int? = nil
    /// Opens the session, from the head's View ›.
    let onView: () -> Void

    @State private var showsAll = false

    // MARK: - Computed

    private var sortedExercises: [SessionExerciseTemplate] {
        (routine.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            BRUSectionHead("Exercises · \(sortedExercises.count)", right: "View ›", rightAction: onView)

            if sortedExercises.isEmpty {
                // Minimal placeholder — not the full empty-state (that's TodayView's job)
                Text("Add an exercise to begin.")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
            } else {
                let shown = showsAll ? sortedExercises.count : min(previewCount ?? .max, sortedExercises.count)
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedExercises.prefix(shown).enumerated()), id: \.element.id) { offset, re in
                        LiftListRow(index: offset + 1, routineExercise: re, phase: phase)
                    }
                }
                if let previewCount, sortedExercises.count > previewCount {
                    TodayGhostRow(title: showsAll ? "Show fewer exercises" : "Show all \(BRUCountLabel.text(sortedExercises.count, "exercise"))") {
                        showsAll.toggle()
                    }
                    .accessibilityIdentifier("today.showAllExercises")
                }
            }
        }
        .background(Color.bruPaper)
    }
}

// MARK: - Preview

#if DEBUG
private struct LiftListSectionPreviewContainer: View {
    let container: ModelContainer
    let routine: SessionTemplate

    var body: some View {
        LiftListSection(routine: routine, phase: nil, onView: {})
            .modelContainer(container)
            .background(Color.bruPaper)
    }

    static func make() -> LiftListSectionPreviewContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: SessionTemplate.self, SessionExerciseTemplate.self, Exercise.self,
            configurations: config
        )
        let fixture: [(String, String, Int, Int, Int)] = [
            ("Bench Press", "compound", 3, 5, 5),
            ("Incline DB Press", "compound", 4, 8, 10),
            ("Cable Fly", "isolation", 3, 12, 15),
            ("Tricep Pushdown", "isolation", 4, 12, 15),
            ("OH Tricep Ext", "isolation", 3, 15, 20),
        ]
        let routine = SessionTemplate()
        routine.name = "Push A"
        container.mainContext.insert(routine)
        for (idx, spec) in fixture.enumerated() {
            let ex = Exercise()
            ex.name = spec.0
            ex.canonicalName = spec.0
            ex.mechanicRaw = spec.1
            let re = SessionExerciseTemplate()
            re.exercise = ex
            re.targetSets = spec.2
            re.targetRepsLow = spec.3
            re.targetRepsHigh = spec.4
            re.sessionTemplate = routine
            re.orderIndex = idx
            container.mainContext.insert(ex)
            container.mainContext.insert(re)
        }
        return LiftListSectionPreviewContainer(container: container, routine: routine)
    }
}

#Preview("LiftListSection — 5 exercises (today.jsx fixture)") {
    LiftListSectionPreviewContainer.make()
}
#endif
