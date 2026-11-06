//
//  BlockNameField.swift
//  fitbod
//
//  Reusable BRU text-input primitive: small uppercase label above a
//  display-type TextField with muted placeholder. Used by
//  NewBlockNameBand in BlockBuilderView.swift.
//

import SwiftUI

// MARK: - Tokens
//
// Mirrors the strict subset of `NewBlockScreenTokens` / `NewBlockType` in
// BlockBuilderView.swift that this primitive needs. Duplication is an
// intentional v1 trade-off; collapse to a shared `internal` BRU token
// namespace once a second consumer (a second BRU primitive) lands.

fileprivate enum BlockNameFieldTokens {
    static let labelTracking: CGFloat = 2.2
}

fileprivate enum BlockNameFieldType {
    static let label        = Font.bru(.grotesk, size: 10)
    static let display      = Font.bru(.condensed, size: 39)
    // 260528-vi2: bumped 44 → 46 for more display presence
    static let displayLarge = Font.bru(.condensed, size: 46)
}

// MARK: - BlockNameField

public struct BlockNameField: View {
    public let title: String
    public let placeholder: String
    @Binding public var text: String
    /// The field's focus, owned by the screen, so it can put the cursor
    /// here when the name is what a save still needs.
    private var isFocused: FocusState<Bool>.Binding
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(title: String, placeholder: String, text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isFocused = isFocused
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(BlockNameFieldType.label)
                .tracking(BlockNameFieldTokens.labelTracking)
                .foregroundStyle(Color.bruMuted)
                .padding(.top, 16)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    // T25: at accessibility sizes the placeholder shrinks to
                    // its one line rather than end in "…".
                    Text(placeholder)
                        .font(BlockNameFieldType.displayLarge)
                        .foregroundStyle(Color.bruMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsHitTesting(false)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    // T38: at accessibility sizes one line holds only part of
                    // a name, so the field wraps it between words onto as many
                    // lines as it needs, rather than cut it off.
                    styled(TextField("", text: $text, axis: .vertical))
                        .submitLabel(.done)
                        .onChange(of: text) { _, newValue in
                            // A vertical field turns Return into a new line;
                            // treat it as done.
                            if newValue.contains("\n") {
                                text = newValue.replacingOccurrences(of: "\n", with: "")
                                isFocused.wrappedValue = false
                            }
                        }
                } else {
                    styled(TextField("", text: $text))
                        .frame(height: 46)
                }
            }
            .padding(.top, 2)
            .contentShape(Rectangle())
            .onTapGesture { isFocused.wrappedValue = true }
        }
    }

    private func styled(_ field: TextField<Text>) -> some View {
        field
            .font(BlockNameFieldType.displayLarge)
            .textInputAutocapitalization(.words)
            .foregroundStyle(Color.bruInk)
            .tint(Color.bruInk)
            .focused(isFocused)
    }
}
