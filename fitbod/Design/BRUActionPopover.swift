// BRUActionPopover.swift
// fitbod
//
// Compact sharp-cornered action popover for BRU menus that need custom
// styling instead of SwiftUI's system confirmationDialog chrome.

import SwiftUI

public struct BRUActionPopoverItem: Identifiable {
    public let id: UUID
    public let title: String
    public let action: @MainActor () -> Void

    public init(
        id: UUID = UUID(),
        title: String,
        action: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.action = action
    }
}

public struct BRUActionPopover: View {
    public let items: [BRUActionPopoverItem]
    public let width: CGFloat

    public init(
        items: [BRUActionPopoverItem],
        width: CGFloat = BRUActionPopoverTokens.width
    ) {
        self.items = items
        self.width = width
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    item.action()
                } label: {
                    Text(item.title)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: BRUActionPopoverTokens.rowHeight)
                        .padding(.horizontal, BRUActionPopoverTokens.horizontalPadding)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(Color.bruHair)
                        .frame(height: BRUActionPopoverTokens.dividerHeight)
                }
            }
        }
        .frame(width: width)
        .background(Color.bruTabSurface)
        .overlay(
            Rectangle()
                .stroke(Color.bruHair, lineWidth: BRUActionPopoverTokens.borderWidth)
        )
    }
}

public enum BRUActionPopoverTokens {
    public static let width: CGFloat = 200
    public static let rowHeight: CGFloat = 40
    public static let horizontalPadding: CGFloat = 16
    public static let dividerHeight: CGFloat = 1
    public static let borderWidth: CGFloat = 1
}

#if DEBUG
#Preview("BRUActionPopover") {
    ZStack(alignment: .topTrailing) {
        Color.bruBg.ignoresSafeArea()
        BRUActionPopover(
            items: [
                BRUActionPopoverItem(title: "+ New block") {},
                BRUActionPopoverItem(title: "+ New routine") {},
            ]
        )
        .padding()
    }
}
#endif
