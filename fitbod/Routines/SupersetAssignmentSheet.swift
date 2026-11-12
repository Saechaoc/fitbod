//
//  SupersetAssignmentSheet.swift
//  fitbod
//
//  One trip to a lift's superset (RM-026, D-152): the sheet names the
//  long-pressed lift and what a superset does, lists the session's lifts
//  to check as its partners, and pairs them with PAIR n LIFTS ▸. It works
//  in a new session too, since it writes only to the draft:
//  RoutineDraft.persist(into:context:) saves the superset with the session,
//  and Discard writes nothing. CANCEL and a swipe change nothing.
//
//  Reference: bru-screens/Fitbod-Session/screens/phase-2--modal-superset.png.
//  Its rest behavior and CLUSTER chip are not built.
//
//  BRU contract: NO accentColor / NO Image(systemName:) / NO Capsule /
//  NO RoundedRectangle / NO .navigationTitle / NO .toolbar
//

import SwiftUI

public struct SupersetAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: RoutineDraft
    /// The long-pressed lift: always in the superset.
    let exercise: RoutineExerciseDraft

    /// The checked lifts, the long-pressed one and its partners.
    @State private var checked: Set<ObjectIdentifier>

    /// A superset pairs two to four lifts.
    static let maxLifts = 4

    public init(draft: RoutineDraft, exercise: RoutineExerciseDraft) {
        self.draft = draft
        self.exercise = exercise
        let group = exercise.supersetGroupID
        _checked = State(initialValue: Set(draft.exercises
            .filter { $0 === exercise || (group != nil && $0.supersetGroupID == group) }
            .map(ObjectIdentifier.init)))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pair 2–4 lifts to do back to back. In the workout, each keeps its own sets and rest.")
                        .font(BRUFont.bodyDefault)
                        .foregroundStyle(Color.bruMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(BRUMetrics.Spacing.gutter)
                    BRUDivider(.hair)
                    let letters = supersetLetters
                    ForEach(Array(draft.exercises.enumerated()), id: \.offset) { index, lift in
                        row(lift, number: index + 1, letters: letters)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(Color.bruPaper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BRUMetrics.Spacing.tight) {
            Text("Long-pressed: \(name(of: exercise))")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
            Text("Add to superset")
                .font(BRUFont.condensedHeading)
                .foregroundStyle(Color.bruInk)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .padding(.top, BRUMetrics.Spacing.section)
        .padding(.bottom, BRUMetrics.Spacing.group)
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }

    /// One lift: its number in the session, a check box, its name, and its
    /// equipment and current superset. The long-pressed lift stays checked.
    private func row(_ lift: RoutineExerciseDraft, number: Int, letters: [UUID: String]) -> some View {
        let id = ObjectIdentifier(lift)
        let isChecked = checked.contains(id)
        let canToggle = lift !== exercise && (isChecked || checked.count < Self.maxLifts)
        let detail = [lift.exercise?.equipment.displayName, lift.supersetGroupID.flatMap { letters[$0] }]
            .compactMap { $0 }
            .joined(separator: " · ")
        return Button {
            if isChecked { checked.remove(id) } else { checked.insert(id) }
        } label: {
            HStack(spacing: BRUMetrics.Spacing.group) {
                Text(String(format: "%02d", number))
                    .font(BRUFont.condensedLabel)
                    .monospacedDigit()
                    .foregroundStyle(Color.bruInk)
                    .accessibilityHidden(true)
                Rectangle()
                    .fill(isChecked ? Color.bruSignal : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(Rectangle().strokeBorder(
                        isChecked || canToggle ? Color.bruInk : Color.bruHair,
                        lineWidth: BRUMetrics.Border.structural))
                    .overlay {
                        if isChecked {
                            Text("✓").font(BRUFont.labelLarge).foregroundStyle(Color.bruOnSignal)
                        }
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name(of: lift))
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(isChecked || canToggle ? Color.bruInk : Color.bruMuted)
                        .multilineTextAlignment(.leading)
                    if !detail.isEmpty {
                        Text(detail)
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
            .frame(maxWidth: .infinity, minHeight: BRUMetrics.primaryActionHeight, alignment: .leading)
            .background(isChecked ? Color.bruSignal.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        // .bruRow draws a row it cannot toggle as is, readable, where .plain
        // fades it, and a drag that starts on a row never toggles it.
        .buttonStyle(.bruRow)
        .disabled(!canToggle)
        .overlay(alignment: .bottom) { BRUDivider(.hair) }
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .accessibilityIdentifier("superset.lift.\(number)")
    }

    /// CANCEL and PAIR n LIFTS ▸, as the session editor's own footer.
    private var footer: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)
            HStack(spacing: 0) {
                BRUButton("Cancel", kind: .ghost, size: .md) { dismiss() }
                Rectangle()
                    .fill(Color.bruInk)
                    .frame(width: 2)
                BRUButton(checked.count < 2 ? "Pick a partner" : "Pair \(checked.count) lifts ▸", kind: .signal, size: .md) {
                    pair()
                }
                .disabled(checked.count < 2)
                .accessibilityIdentifier("superset.pair")
            }
            // The separator has no height of its own; see BottomActionBar.
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.bruPaper.ignoresSafeArea(edges: .bottom))
    }

    private func pair() {
        let partners = draft.exercises.filter { $0 !== exercise && checked.contains(ObjectIdentifier($0)) }
        draft.setSuperset(of: exercise, partners: partners)
        dismiss()
    }

    /// "Superset A" for the session's first superset, B for the next.
    private var supersetLetters: [UUID: String] {
        var letters: [UUID: String] = [:]
        for id in draft.exercises.compactMap(\.supersetGroupID) where letters[id] == nil {
            letters[id] = "Superset \(String(UnicodeScalar(UInt8(65 + min(letters.count, 25)))))"
        }
        return letters
    }

    private func name(of lift: RoutineExerciseDraft) -> String {
        lift.exercise?.name ?? "Exercise"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SupersetAssignmentSheet — three lifts") {
    let draft = RoutineDraft()
    for _ in 0..<3 { draft.exercises.append(RoutineExerciseDraft()) }
    return SupersetAssignmentSheet(draft: draft, exercise: draft.exercises[0])
}
#endif
