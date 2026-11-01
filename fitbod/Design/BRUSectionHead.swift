// BRUSectionHead.swift
// fitbod
//
// BRU section-divider row — 2pt bruInk top + bottom rules sandwiching
// a bruPaper strip with an UPPERCASE left title and optional right metadata.
//
// Source of truth: UI-SPEC v2 § Component Inventory, line 513.
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor / NO Image(systemName:)
//
// USAGE:
//   BRUSectionHead("Lift list")
//   BRUSectionHead("Lift list", right: "Tap to reorder")
//   BRUSectionHead("Past sessions", right: "14 sessions")
//   BRUSectionHead("Phases", right: "+ ADD PHASE", rightAction: { ... })  // tappable right

import SwiftUI

// MARK: - BRUSectionHead

/// A section-divider row with 2pt ink rules top + bottom and an uppercase title.
///
/// Layout:
/// ```
/// ┌─────────────────────────────────────────────────────┐ ← 2pt bruInk rule
/// │  LIFT LIST                          Tap to reorder  │ ← bruPaper fill, 16pt h-pad, 12pt v-pad
/// └─────────────────────────────────────────────────────┘ ← 2pt bruInk rule
/// ```
/// - Title: `.bru(.grotesk, size: 14)`, tracking 0, uppercase transform.
/// - Right metadata: `BRUFont.labelSmall`, tracking 1.2, uppercase transform.
///   - When `rightAction` is `nil`: renders in `bruMuted` (display only).
///   - When `rightAction` is non-nil: renders in `bruSignal` and is tappable.
/// - Accessibility sizes: the right metadata sits under the title, so the
///   title has the full width and breaks only between its words.
/// - Accessibility: adds `.isHeader` trait so VoiceOver announces the section.
public struct BRUSectionHead: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Properties

    private let title: String
    private let right: String?
    private let rightAction: (() -> Void)?

    // MARK: - Init

    /// Creates a BRU section-divider row.
    /// - Parameters:
    ///   - title: The section heading. Rendered uppercase at the view layer — source string
    ///            is as-typed for VoiceOver.
    ///   - right: Optional right-side metadata string (e.g. "Tap to reorder", "14 sessions",
    ///            "+ ADD PHASE"). Rendered uppercase labelSmall. Pass `nil` (default) to omit.
    ///   - rightAction: Optional tap closure for the right label. When provided, the right
    ///                  label renders in `bruSignal` (instead of `bruMuted`) and is tappable.
    ///                  Used by Phase 04.1 surfaces for "+ADD PHASE" actions per UI-SPEC line 513.
    public init(_ title: String, right: String? = nil, rightAction: (() -> Void)? = nil) {
        self.title = title
        self.right = right
        self.rightAction = rightAction
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            BRUDivider(.ink)

            rowLayout {
                Text(title)
                    .font(.bru(.grotesk, size: 14))
                    .tracking(0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.bruInk)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                if let right {
                    if let action = rightAction {
                        // Tappable variant — bruSignal color per UI-SPEC line 513
                        Button(action: action) {
                            Text(right)
                                .font(BRUFont.labelSmall)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.bruSignalText)
                                .bruHitArea()
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Display-only variant — bruMuted color (original behavior)
                        Text(right)
                            .font(BRUFont.labelSmall)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bruMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.bruPaper)

            BRUDivider(.ink)
        }
        // VoiceOver announces the section head as a header landmark (UI-SPEC line 688).
        .accessibilityAddTraits(.isHeader)
    }

    /// One row at standard sizes. At accessibility sizes the right label
    /// goes under the title: beside it, the title's longest word could
    /// outgrow the width left over and break mid-word ("PERFORMANC" over
    /// "E").
    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BRUMetrics.Spacing.tight))
            : AnyLayout(HStackLayout())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BRUSectionHead") {
    VStack(spacing: 0) {
        BRUSectionHead("Lift list", right: "Tap to reorder")

        // Simulate list rows between section heads
        VStack(spacing: 0) {
            HStack {
                Text("Bench Press")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            BRUDivider(.hair)

            HStack {
                Text("Barbell Row")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }

        BRUSectionHead("Phases", right: "+ ADD PHASE", rightAction: {})

        BRUSectionHead("Past sessions")

        VStack(spacing: 0) {
            HStack {
                Text("No right metadata variant above")
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    .background(Color.bruPaper)
}
#endif
