// A live review surface for the small native BRU design system.
// DEBUG only: sample controls change local state, never the user's workout data.

#if DEBUG
import SwiftUI

struct BRUComponentGallery: View {
    @Environment(\.dismiss) private var dismiss
    @State private var lastAction = "Tap a sample to review its interaction."
    @State private var sets = 3
    @State private var rest = 120
    @State private var plates = 2
    @State private var autoWarmup = true
    @State private var complete = false
    @State private var units = "kg"
    @State private var selectedTab = BRUTab.today
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            BRUHeaderBar(left: HeaderAction("‹ Back") { dismiss() }, center: "Component gallery")
            Text(lastAction)
                .font(BRUFont.bodyDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.bruBg2)
                .accessibilityIdentifier("gallery.lastAction")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("Live native components. Changes here are examples and do not modify training data.")
                        .font(BRUFont.bodyDefault)
                        .padding(16)
                    BRUSectionHead("Actions", right: "Tap to try")
                    samples {
                        BRUButton("Primary action") { didTap("Primary button") }
                        BRUButton("Signal action ▸", kind: .signal, size: .lg) { didTap("Signal button") }
                        BRUButton("Secondary action", kind: .ghost) { didTap("Ghost button") }
                        BRUButton("Compact action", kind: .ghost, size: .sm) { didTap("Compact button") }
                        BRUButton("Unavailable", kind: .signal) {}.disabled(true)
                        BRUPillButton("Start workout ▸") { didTap("Full-width CTA") }
                        BRUDashedSlot(label: "Add exercise", hint: "From library") { didTap("Add exercise slot") }
                        Button("Small link with expanded hit area") { didTap("Expanded link") }
                            .font(BRUFont.labelSmall)
                            .bruHitArea()
                            .buttonStyle(.plain)
                    }

                    BRUSectionHead("Inputs")
                    samples {
                        BRUStepper("Target sets", value: $sets, in: 1...10, step: 1) { "\($0)" }
                        BRUStepper("Rest duration", value: $rest, in: 30...600, step: 15) {
                            "\($0 / 60):\(String(format: "%02d", $0 % 60))"
                        }
                        BRUSegmentedControl("Weight units", options: ["kg", "lb"], selection: $units) { $0 }
                        Toggle("Automatic warm-up sets", isOn: $autoWarmup).toggleStyle(.bru)
                        TextField("Search exercises", text: $search)
                            .font(BRUFont.bodyDefault)
                            .padding(12)
                            .frame(minHeight: 44)
                            .overlay(Rectangle().strokeBorder(Color.bruInk, lineWidth: 1.5))
                            .accessibilityLabel("Example exercise search")
                        Text(search.isEmpty ? "Empty search" : "Search: \(search)")
                            .font(BRUFont.bodyDefault)
                        PlateTallyRow(weight: 20, count: $plates, unitLabel: units)
                    }

                    BRUSectionHead("Chips and wrapping")
                    samples {
                        BRUFlowLayout(spacing: 8) {
                            BRUChip("Barbell")
                            BRUChip("Chest", fill: true)
                            BRUChip("Hypertrophy")
                            BRUChip("Long exercise and equipment labels", textCase: nil)
                        }
                        HStack {
                            BRUCornerBadge("PR")
                            BRUCornerBadge("DL", fill: .bruInk, textColor: .bruPaper)
                        }
                    }

                    BRUSectionHead("Set completion")
                    samples {
                        Button {
                            complete.toggle()
                            didTap(complete ? "Set completed" : "Set reopened")
                        } label: {
                            HStack(spacing: 12) {
                                SetCompletionGlyph(isComplete: complete)
                                    .frame(width: 44, height: 44)
                                Text("80 \(units) × 8 reps")
                                    .font(BRUFont.bodyEmphasis)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(complete ? "Reopen example set" : "Complete example set")
                        .accessibilityValue(complete ? "Complete" : "Incomplete")
                        CalibratingProgressMeter(current: 8, threshold: 10, rangeText: "75–85 \(units)")
                    }

                    BRUSectionHead("Metrics and charts")
                    samples {
                        BRUReadout(label: "Working weight", value: "80 \(units)")
                        BRUReadout(label: "Completed sets", value: complete ? "1 / \(sets)" : "0 / \(sets)")
                        BRUSpark(values: [8, 10, 9, 12, 11, 14, 13, 16])
                            .frame(height: 64)
                        PlateStackViz(platesPerSide: [], barLabel: "20 \(units) bar")
                    }

                    BRUSectionHead("Structure")
                    samples {
                        BRUSupersetBracket {
                            Text("A1 · Incline Dumbbell Press · 3 × 8–12")
                                .font(BRUFont.bodyEmphasis)
                            Text("A2 · Chest Supported Dumbbell Row · 3 × 10–12")
                                .font(BRUFont.bodyEmphasis)
                        }
                        LiveEditBanner()
                        BRUDivider(.ink)
                        BRUDivider(.hair)
                        BRUActionPopover(items: [
                            BRUActionPopoverItem(title: "New session") { didTap("New session menu item") },
                            BRUActionPopoverItem(title: "New routine") { didTap("New routine menu item") }
                        ])
                    }

                    BRUSectionHead("Typography")
                    samples {
                        Text("TRAIN WITH PURPOSE").font(BRUFont.condensedTitle)
                        BRUDisplay("Barbell Bench Press", size: .medium)
                        Text("80 × 8 · Rest 2:00").font(BRUFont.bodyEmphasis)
                        Text("Secondary training metadata").font(BRUFont.bodyDefault)
                        Text("Section label").font(BRUFont.labelLarge)
                        Text("Equipment label").font(BRUFont.labelSmall)
                        Text("PR badge only").font(BRUFont.labelMicro)
                    }

                    BRUSectionHead("Tab bar", right: selectedTab.label)
                    BRUTabBar(active: selectedTab) {
                        selectedTab = $0
                        didTap("\($0.label) tab")
                    }
                }
            }
        }
        .foregroundStyle(Color.bruInk)
        .background(Color.bruPaper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func samples<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    private func didTap(_ action: String) {
        lastAction = "\(action) activated."
    }
}

#Preview("BRU live gallery") {
    NavigationStack { BRUComponentGallery() }
}

#Preview("BRU gallery · accessibility") {
    NavigationStack { BRUComponentGallery() }
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("BRU gallery · dark") {
    NavigationStack { BRUComponentGallery() }
        .preferredColorScheme(.dark)
}
#endif
