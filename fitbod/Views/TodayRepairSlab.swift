import SwiftUI

/// A repair keeps its action on Today's stack and uses the shared ink button.
struct TodayRepairSlab: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BRUFont.condensedHeading)
                .textCase(.uppercase)
                .foregroundStyle(Color.bruInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(BRUFont.bodyDefault)
                .foregroundStyle(Color.bruMuted)
                .fixedSize(horizontal: false, vertical: true)
            BRUButton(actionTitle, kind: .primary, size: .lg, action: action)
                .accessibilityIdentifier("today.repair")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bruPaper)
        .overlay { Rectangle().strokeBorder(Color.bruInk, lineWidth: 2) }
        .padding(16)
    }
}
