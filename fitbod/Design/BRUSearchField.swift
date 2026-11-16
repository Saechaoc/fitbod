// BRUSearchField.swift
// fitbod
//
// The search row of the Library mock-up (phase-1--library.png): ⌕, the
// query in mono, × to clear it once it has text, and a 2pt ink rule below.
// The row is 56pt tall, and a tap anywhere on it puts the cursor in the
// query. Return, labeled search, puts the keyboard away. The Library and
// its pickers search exercises with it, and the custom exercise editor's
// family list searches families.

import SwiftUI

public struct BRUSearchField: View {
    private let prompt: String
    @Binding private var text: String
    private let focus: FocusState<Bool>.Binding
    private let identifier: String
    private let onCommit: (String) -> Void

    /// - Parameters:
    ///   - prompt: The placeholder, and the field's VoiceOver label ("Search exercises").
    ///   - text: The query.
    ///   - focus: Whether the query has the cursor, so the owner can take it away.
    ///   - identifier: The field's accessibility identifier.
    ///   - onCommit: Gets the query once it is final: after return, and the
    ///     empty query after ×. The Library searches at once then, without
    ///     its pause for typing.
    public init(
        _ prompt: String,
        text: Binding<String>,
        focus: FocusState<Bool>.Binding,
        identifier: String,
        onCommit: @escaping (String) -> Void = { _ in }
    ) {
        self.prompt = prompt
        self._text = text
        self.focus = focus
        self.identifier = identifier
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text("⌕")
                .font(BRUFont.condensedHeading)
                .foregroundStyle(Color.bruMuted)
                .accessibilityHidden(true)
            TextField(
                text: $text,
                // The system placeholder gray reads at 1.7:1 on paper;
                // bruMuted reads at 4.5:1 or more in light and dark mode.
                prompt: Text(prompt).foregroundStyle(Color.bruMuted)
            ) {
                Text(prompt)
            }
            .font(.bru(.mono, size: 17))
            .foregroundStyle(Color.bruInk)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused(focus)
            .onSubmit {
                onCommit(text)
                focus.wrappedValue = false
            }
            .accessibilityLabel(prompt)
            .accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button {
                    text = ""
                    onCommit("")
                } label: {
                    Text("×")
                        .font(BRUFont.condensedHeading)
                        .foregroundStyle(Color.bruInk)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, BRUMetrics.Spacing.gutter)
        .frame(minHeight: 56)
        .background(Color.bruPaper)
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = true }
        .overlay(alignment: .bottom) { BRUDivider(.ink) }
    }
}

#if DEBUG
#Preview("BRUSearchField") {
    @Previewable @State var empty = ""
    @Previewable @State var typed = "bench"
    @Previewable @FocusState var emptyFocused: Bool
    @Previewable @FocusState var typedFocused: Bool
    VStack(spacing: 0) {
        BRUSearchField("Search exercises", text: $empty, focus: $emptyFocused, identifier: "preview.empty")
        BRUSearchField("Search families", text: $typed, focus: $typedFocused, identifier: "preview.typed")
        Spacer()
    }
    .background(Color.bruPaper)
}
#endif
