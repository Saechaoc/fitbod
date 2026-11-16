// ExerciseLinkRow.swift
// fitbod
//
// A full-width row that opens another screen of one exercise: its history,
// its chart or its records. The exercise's page, history and chart share
// it, so each reaches the others the same way (RM-023).
//
// BRU contract: NO Capsule() / NO RoundedRectangle / NO accentColor /
//               NO Image(systemName:) / NO Color(.system*) /
//               NO .font(.body/.headline/.title*/caption)

import SwiftUI

/// "View records ›": the title, then a "›" that VoiceOver skips, under a
/// hair rule. It pushes a view rather than a route, so it works on the
/// stack of whichever tab shows the exercise, Progress's or Library's.
struct ExerciseLinkRow<Destination: View>: View {
    let title: String
    let destination: Destination

    init(_ title: String, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Text(title)
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Spacer()
                Text("›")
                    .font(BRUFont.displayMedium)
                    .foregroundStyle(Color.bruMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { BRUDivider(.hair) }
        }
        .buttonStyle(.bruRow)
    }
}
