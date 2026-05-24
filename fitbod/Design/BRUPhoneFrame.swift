// BRUPhoneFrame.swift
// fitbod — Phase 2.1 Plan 03
//
// DEBUG-ONLY preview wrapper that adds a phone-bezel-like background so
// previews in Plans 02.1-04..09 match the bru-screens/*.jsx mockups.
//
// NOT used in production code. The #if DEBUG guard ensures zero impact on
// release builds. Do not reference BRUPhoneFrame from any non-preview context.
//
// SIZE: 390×844pt — iPhone 14/15 logical point dimensions.
//
// USAGE (in a #Preview block):
//   BRUPhoneFrame {
//       BRUHeaderBar(center: "Routines")
//       Text("Body content here")
//       Spacer()
//   }

#if DEBUG
import SwiftUI

// MARK: - BRUPhoneFrame

/// Preview-only phone-bezel wrapper.
///
/// Renders a 390×844pt canvas with:
/// - A status-bar row (9:41 mock time, bruBg background)
/// - The wrapped content area
/// - A 1pt bruInk outer border (no rounded corners — BRU brutalist)
///
/// Minimum viable wrapper: no SVG bezel, no Image(systemName:), no Capsule.
public struct BRUPhoneFrame<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mock status bar row
            HStack {
                Text("9:41")
                    .font(BRUFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(Color.bruInk)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color.bruBg)

            content
        }
        .background(Color.bruPaper)
        .frame(width: 390, height: 844)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(Color.bruInk, lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("BRUPhoneFrame — Header + Body") {
    BRUPhoneFrame {
        BRUHeaderBar(
            left: HeaderAction("‹ Back") {},
            center: "Today"
        )
        VStack(alignment: .leading, spacing: 16) {
            Text("Content area")
                .font(BRUFont.bodyEmphasis)
                .foregroundStyle(Color.bruInk)
                .padding(.horizontal, 16)
            Spacer()
        }
    }
}
#endif
