// NewRoutineNameScreen.swift
// fitbod
//
// The name step "+ New routine" opens on Program and on Today, modeled on
// BruNewRoutineScreen in bru-screens/create-flows.jsx (tradeoffs.md "New
// routine flow"). Only the name is built here; the mockup's other fields
// belong to the full inline creator on the roadmap.
//
// The header holds ‹ BACK, "New routine" and SAVE, which stays muted and
// disabled until the trimmed name is not empty. Nothing is saved before
// SAVE, so ‹ BACK and the edge swipe leave no routine behind. SAVE creates
// the routine (code `Split`) through RoutineCreator, and the tab's stack
// puts the routine's editor in the step's place, so Back from the editor
// returns to where the user started.
//
// Navigation: pushed with `NewRoutineRoute.name` on the tab's own stack,
// which registers it with `newRoutineDestination(path:)`.
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI
import SwiftData

public enum NewRoutineRoute: Hashable, Sendable {
    /// The name step of a routine that does not exist yet.
    case name
}

extension View {
    /// Registers the name step on the enclosing NavigationStack. SAVE swaps
    /// the step for the saved routine's editor, so the step never stays
    /// under it.
    func newRoutineDestination(path: Binding<NavigationPath>) -> some View {
        navigationDestination(for: NewRoutineRoute.self) { _ in
            NewRoutineNameScreen { split in
                var stack = path.wrappedValue
                if !stack.isEmpty { stack.removeLast() }
                stack.append(SplitDetailRoute.detail(splitID: split.id))
                path.wrappedValue = stack
            }
        }
    }
}

// MARK: - NewRoutineNameScreen

public struct NewRoutineNameScreen: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    /// Receives the saved routine, so the caller can open its editor.
    private let onSave: (Split) -> Void

    @State private var name = ""
    @State private var isSaved = false
    @State private var showSaveError = false
    @FocusState private var nameFocused: Bool

    public init(onSave: @escaping (Split) -> Void) {
        self.onSave = onSave
    }

    /// The name SAVE would give the routine.
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(
                left: HeaderAction("‹ Back") { dismiss() },
                center: "New routine",
                right: HeaderAction("Save", isSignal: true, isEnabled: !trimmedName.isEmpty && !isSaved) { save() }
            )

            ScrollView {
                nameSection
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { nameFocused = true }
        .alert("Couldn't Save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't save. Try again.")
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Routine name")
                .font(BRUFont.labelSmall)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
            ZStack(alignment: .leading) {
                if name.isEmpty {
                    // SwiftUI cuts a long prompt short with "…" at
                    // accessibility sizes, so the field's prompt draws clear,
                    // for VoiceOver only, and this copy shrinks to fit instead.
                    Text("Name your routine")
                        .font(BRUFont.condensedTitle)
                        .foregroundStyle(Color.bruMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                nameField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }

    private var nameField: some View {
        TextField(
            "Routine name",
            text: $name,
            prompt: Text("Name your routine").foregroundStyle(Color.clear),
            axis: .vertical
        )
        .font(BRUFont.condensedTitle)
        .foregroundStyle(Color.bruInk)
        .tint(Color.bruInk)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .focused($nameFocused)
        .submitLabel(.done)
        .onChange(of: name) { _, value in
            // A vertical-axis field types Return as "\n"; here it only ends
            // editing. SAVE is the one way to create the routine.
            guard value.contains("\n") else { return }
            name = value
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            nameFocused = false
        }
        .accessibilityLabel("Routine name")
        .accessibilityIdentifier("newRoutine.name")
    }

    // MARK: - Save

    private func save() {
        guard !trimmedName.isEmpty, !isSaved else { return }
        guard let split = RoutineCreator.create(named: trimmedName, context: ctx) else {
            showSaveError = true
            return
        }
        isSaved = true
        nameFocused = false
        onSave(split)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("New routine - name step") {
    NavigationStack {
        NewRoutineNameScreen { _ in }
    }
    .modelContainer(PreviewModelContainer.make(seedFixture: false))
}
#endif
