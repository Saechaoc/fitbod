//
//  RoutineExerciseCard.swift
//  fitbod
//
//  One exercise in the routine builder. Collapsed it reads like the
//  routine table ("1 · Barbell Bench Press — STRENGTH · 4 × 4–6 · RPE 8 ·
//  3:00"); tap the header to expand the prescription steppers. The ⋯ menu
//  offers Move up / Move down (reordering without drag, for VoiceOver and
//  one-handed use), Duplicate, superset grouping, warm-up settings and
//  Remove.
//
//  Superset membership is shown as a SUPERSET tag (no accent rail — the
//  accent is reserved for primary actions).
//

import SwiftUI

public struct RoutineExerciseCard: View {
    @Bindable public var draft: RoutineExerciseDraft
    let index: Int
    let count: Int
    @Binding public var isExpanded: Bool

    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onAssignSuperset: (RoutineExerciseDraft) -> Void
    let onRemoveFromSuperset: (RoutineExerciseDraft) -> Void
    let onDuplicate: (RoutineExerciseDraft) -> Void
    let onRemove: (RoutineExerciseDraft) -> Void
    let onEditWarmup: (RoutineExerciseDraft) -> Void

    public init(
        draft: RoutineExerciseDraft,
        index: Int,
        count: Int,
        isExpanded: Binding<Bool>,
        onMoveUp: @escaping () -> Void = {},
        onMoveDown: @escaping () -> Void = {},
        onAssignSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemoveFromSuperset: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onDuplicate: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onRemove: @escaping (RoutineExerciseDraft) -> Void = { _ in },
        onEditWarmup: @escaping (RoutineExerciseDraft) -> Void = { _ in }
    ) {
        self.draft = draft
        self.index = index
        self.count = count
        self._isExpanded = isExpanded
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onAssignSuperset = onAssignSuperset
        self.onRemoveFromSuperset = onRemoveFromSuperset
        self.onDuplicate = onDuplicate
        self.onRemove = onRemove
        self.onEditWarmup = onEditWarmup
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Chalk.Space.md) {
            HStack(alignment: .top, spacing: Chalk.Space.sm) {
                Button {
                    withAnimation(.easeInOut(duration: Chalk.Motion.quick)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: Chalk.Space.sm) {
                        VStack(alignment: .leading, spacing: Chalk.Space.xs) {
                            Text("\(index + 1) · \(draft.exercise?.name ?? "Exercise")")
                                .font(.chalkHeadline)
                                .foregroundStyle(.chalkInk)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: Chalk.Space.sm) {
                                ChalkTag(draft.intent.rawValue, style: draft.intent == .strength ? .solid : .outline)
                                if draft.supersetGroupID != nil {
                                    ChalkTag("Superset", style: .subtle)
                                }
                            }
                            Text(summary)
                                .font(.chalkFootnote)
                                .foregroundStyle(.chalkInk2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.chalkInk3)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(Text(isExpanded ? "expanded" : "collapsed"))
                .accessibilityHint(Text(isExpanded ? "Collapses the prescription" : "Edits sets, reps, RPE and rest"))
                .accessibilityIdentifier("builder.exercise.\(index)")

                Menu {
                    Button {
                        onMoveUp()
                    } label: {
                        Label("Move up", systemImage: "arrow.up")
                    }
                    .disabled(index == 0)
                    Button {
                        onMoveDown()
                    } label: {
                        Label("Move down", systemImage: "arrow.down")
                    }
                    .disabled(index >= count - 1)
                    Divider()
                    Button {
                        onDuplicate(draft)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    if draft.supersetGroupID == nil {
                        Button {
                            onAssignSuperset(draft)
                        } label: {
                            Label("Add to superset…", systemImage: "link")
                        }
                    } else {
                        Button {
                            onRemoveFromSuperset(draft)
                        } label: {
                            Label("Remove from superset", systemImage: "link.badge.plus")
                        }
                    }
                    Button {
                        onEditWarmup(draft)
                    } label: {
                        Label("Warm-up settings…", systemImage: "flame")
                    }
                    Divider()
                    Button(role: .destructive) {
                        onRemove(draft)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    ChalkIconGlyph(systemImage: "ellipsis")
                }
                .accessibilityLabel(Text("Options for \(draft.exercise?.name ?? "exercise")"))
                .accessibilityIdentifier("builder.exercise.\(index).menu")
            }

            if isExpanded {
                PrescriptionEditorRow(
                    draft: draft,
                    identifierPrefix: "builder.\(index)",
                    onEditWarmup: { onEditWarmup(draft) }
                )
                .transition(.opacity)
            }
        }
        .padding(.vertical, Chalk.Space.xs)
    }

    /// "4 × 4–6 · RPE 8 · rest 3:00"
    private var summary: String {
        let reps = draft.targetRepsLow == draft.targetRepsHigh
            ? "\(draft.targetRepsLow)"
            : "\(draft.targetRepsLow)–\(draft.targetRepsHigh)"
        var parts = ["\(draft.targetSets) × \(reps)"]
        if let rpe = draft.targetRPE {
            parts.append("RPE \(ChalkFormat.rpe(rpe))")
        }
        parts.append("rest \(ChalkFormat.duration(seconds: draft.prescribedRestSeconds))")
        return parts.joined(separator: " · ")
    }
}
