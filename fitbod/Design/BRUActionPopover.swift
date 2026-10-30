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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// How far the titles have grown from their default size;
    /// `BRUFont.displayMedium` scales like `.title3`.
    @ScaledMetric(relativeTo: .title3) private var textScale: CGFloat = 1

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
                    // A title too long for the row wraps, and the row grows
                    // with it past its 44pt minimum.
                    Text(item.title)
                        .font(BRUFont.displayMedium)
                        .foregroundStyle(Color.bruInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, BRUActionPopoverTokens.verticalPadding)
                        .frame(maxWidth: .infinity, minHeight: BRUActionPopoverTokens.rowHeight, alignment: .leading)
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
        // At accessibility sizes the popover widens with its titles, up to
        // the width it is offered less a gutter, so it stays on screen.
        .frame(minWidth: width, maxWidth: dynamicTypeSize.isAccessibilitySize ? width * textScale : width)
        .background(Color.bruTabSurface)
        .overlay(
            Rectangle()
                .stroke(Color.bruHair, lineWidth: BRUActionPopoverTokens.borderWidth)
        )
        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? BRUMetrics.Spacing.gutter : 0)
    }
}

public enum BRUActionPopoverTokens {
    public static let width: CGFloat = 200
    /// The least row height, a 44pt tap target. Larger text grows the row.
    public static let rowHeight: CGFloat = 44
    public static let horizontalPadding: CGFloat = 16
    /// Keeps a wrapped title clear of the rules above and below its row.
    public static let verticalPadding: CGFloat = 8
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
