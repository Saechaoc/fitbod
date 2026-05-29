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
    static let ink   = Color(red: 10 / 255,  green: 10 / 255,  blue: 10 / 255)
    static let muted = Color(red: 126 / 255, green: 123 / 255, blue: 114 / 255)
    static let labelTracking: CGFloat = 2.2
}

fileprivate enum BlockNameFieldType {
    static let label        = Font.custom("SpaceGrotesk-Bold", size: 10)
    static let display      = Font.custom("BebasNeue-Regular", size: 39)
    // 260528-vi2: bumped 44 → 46 for more display presence
    static let displayLarge = Font.custom("BebasNeue-Regular", size: 46)
}

// MARK: - BlockNameField

public struct BlockNameField: View {
    public let title: String
    public let placeholder: String
    @Binding public var text: String

    @FocusState private var isFocused: Bool

    public init(title: String, placeholder: String, text: Binding<String>) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(BlockNameFieldType.label)
                .tracking(BlockNameFieldTokens.labelTracking)
                .foregroundStyle(BlockNameFieldTokens.muted)
                .padding(.top, 16)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(BlockNameFieldType.displayLarge)
                        .foregroundStyle(BlockNameFieldTokens.muted)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
                    .font(BlockNameFieldType.displayLarge)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(BlockNameFieldTokens.ink)
                    .tint(BlockNameFieldTokens.ink)
                    .focused($isFocused)
                    .frame(height: 46)
            }
            .padding(.top, 2)
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
        }
    }
}
