//
//  StoreOpenFailedView.swift
//  fitbod
//
//  Shown in place of the app when `FitbodModelContainer.make()` throws.
//  The store files are still on the phone in every such case, so the screen
//  says so and offers "Try again", which opens the store again. A retry
//  that works replaces this screen with the app and its workouts.
//
//  The last line carries the error's domain and code, because the screen is
//  the only place a lifter in the gym can read why the store did not open.
//

import SwiftUI

struct StoreOpenFailedView: View {
    let error: any Error
    let retry: () -> Void

    /// Failed retries from this screen, so a retry that changes nothing
    /// still answers the tap.
    @State private var failedRetries = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BRUMetrics.Spacing.group) {
                Text("Training data did not open")
                    .font(BRUFont.condensedTitle)
                    .foregroundStyle(Color.bruInk)
                    .accessibilityAddTraits(.isHeader)
                Text("Your workouts are still on this phone. Nothing was deleted.")
                    .font(BRUFont.bodyEmphasis)
                    .foregroundStyle(Color.bruInk)
                Text("Try again. If it still does not open, close the app and open it again, or restart the phone.")
                Text("Do not delete the app. Deleting it erases your training data.")

                BRUButton("Try again", kind: .signal, size: .lg) {
                    // Still on this screen after `retry` means it failed again.
                    failedRetries += 1
                    retry()
                }
                .padding(.top, BRUMetrics.Spacing.group)

                if failedRetries > 0 {
                    Text("It still did not open. Tries: \(failedRetries).")
                        .foregroundStyle(Color.bruInk)
                }
                Text(FitbodModelContainer.summary(of: error))
                    .padding(.top, BRUMetrics.Spacing.group)
            }
            .font(BRUFont.bodyDefault)
            .foregroundStyle(Color.bruMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BRUMetrics.Spacing.gutter)
        }
        .background(Color.bruPaper)
    }
}

#Preview("Store did not open") {
    StoreOpenFailedView(error: CocoaError(.fileReadNoPermission)) {}
}
