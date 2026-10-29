import SwiftUI

/// Shared visual measurements. Colors and typography have their own namespaces.
public enum BRUMetrics {
    public enum Spacing {
        public static let tight: CGFloat = 4
        public static let related: CGFloat = 8
        public static let group: CGFloat = 12
        public static let gutter: CGFloat = 16
        public static let section: CGFloat = 24
        public static let hero: CGFloat = 32
    }

    public enum Border {
        public static let hairline: CGFloat = 1
        public static let outline: CGFloat = 1.5
        public static let structural: CGFloat = 2
    }

    public static let cornerRadius: CGFloat = 0
    public static let touchTarget: CGFloat = 44
    public static let primaryActionHeight: CGFloat = 52
}

#if DEBUG
#Preview("BRU spacing and boundaries") {
    VStack(alignment: .leading, spacing: BRUMetrics.Spacing.group) {
        Text("44pt targets · 16pt gutters · square corners").font(BRUFont.bodyDefault)
        BRUButton("Primary action ▸", kind: .signal, size: .lg) {}
        BRUButton("Compact label · full touch target", kind: .ghost, size: .sm) {}
    }
    .padding(BRUMetrics.Spacing.gutter)
    .background(Color.bruPaper)
}
#endif
