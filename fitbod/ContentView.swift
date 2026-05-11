//
//  ContentView.swift
//  fitbod
//
//  Interim `RootView` stub. The Wave-3 `RootView` (plan 03-01) replaces
//  this with a `TabView` hosting Today / Routines / Library / Settings
//  and moves the file to `fitbod/App/RootView.swift`. Keeping the file
//  named `ContentView.swift` for this plan minimizes pbxproj thrash —
//  03-01 owns the rename + folder move as a single atomic change.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Fitbod")
                .font(.title2.weight(.semibold))
            Text("Wave 3 fills this in.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview { RootView() }
