//
//  BlockCard.swift
//  fitbod
//
//  Today-tab card for the active periodization block.
//

import SwiftData
import SwiftUI

public struct BlockCard: View {
    @Environment(\.modelContext) private var ctx

    public let block: Block

    @State private var selectedWeekIndex = 0
    @State private var pendingBuilderForEdit: Block? = nil
    @State private var pendingEndConfirm: Block? = nil

    public init(block: Block) {
        self.block = block
    }

    public var body: some View {
        cardBody(active: block)
            .sheet(item: $pendingBuilderForEdit) { block in
                NavigationStack {
                    BlockBuilderView(draft: BlockDraft(block: block), editing: block)
                }
            }
            .alert(
                "End block?",
                isPresented: Binding(
                    get: { pendingEndConfirm != nil },
                    set: { if !$0 { pendingEndConfirm = nil } }
                )
            ) {
                Button("End Block", role: .destructive) {
                    if let target = pendingEndConfirm {
                        do {
                            try ctx.transaction {
                                target.isActive = false
                                try ctx.save()
                            }
                        } catch {
                            // Offline single-user write; keep the card visible if the save fails.
                        }
                    }
                    pendingEndConfirm = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingEndConfirm = nil
                }
            } message: {
                Text("End this block now? You can review it from the Routines tab.")
            }
    }

    public static func initialSelectedWeekIndex(for block: Block, on date: Date = .now) -> Int {
        PeriodizationEngine.weekIndex(for: block, on: date) ?? 0
    }

    @ViewBuilder
    private func cardBody(active: Block) -> some View {
        let totalWeeks = MesocycleWeekPage.totalWeeks(of: active)
        if totalWeeks > 0 {
            VStack(spacing: 0) {
                HStack {
                    Text(active.name)
                        .font(.headline)
                    Spacer()
                    overflowMenu(for: active)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                TabView(selection: $selectedWeekIndex) {
                    ForEach(0..<totalWeeks, id: \.self) { weekIndex in
                        MesocycleWeekPage(block: active, weekIndex: weekIndex)
                            .tag(weekIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 200)
            }
            .background(BlockPhaseColors.tint(for: selectedPhaseKind(for: active)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityHint("Swipe horizontally to navigate between weeks of the mesocycle.")
            .onAppear {
                selectedWeekIndex = Self.initialSelectedWeekIndex(for: active)
            }
        }
    }

    private func selectedPhaseKind(for block: Block) -> BlockPhaseKind {
        PeriodizationEngine
            .weekContext(for: block, weekIndex: selectedWeekIndex, on: .now)?
            .phaseKind ?? .accumulation
    }

    private func overflowMenu(for block: Block) -> some View {
        Menu {
            Button("Edit Block") {
                pendingBuilderForEdit = block
            }
            Button("End Block", role: .destructive) {
                pendingEndConfirm = block
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Block actions")
    }
}
