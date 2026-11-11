//
//  NewBlockBuilderFidelityTests.swift
//  fitbodTests
//
//  Draft and rendered-layout guardrails for the New Block modal fidelity pass.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
import Vision
@testable import fitbod

@Suite("New Block builder fidelity")
struct NewBlockBuilderFidelityTests {

    @MainActor
    @Test("New block draft matches the blank modal mock defaults")
    func newBlockDraftMatchesBlankModalDefaults() {
        let draft = BlockDraft.newBlock()

        #expect(draft.name.isEmpty)
        #expect(!draft.isActive)
        #expect(draft.totalWeeks == 5)
        #expect(draft.phases.count == 3)

        #expect(draft.phases[0].kind == .accumulation)
        #expect(draft.phases[0].weeks == 2)
        #expect(draft.phases[0].volumeMultiplier == 1.2)
        #expect(draft.phases[0].intensityMultiplier == 0.70)

        #expect(draft.phases[1].kind == .intensification)
        #expect(draft.phases[1].weeks == 2)
        #expect(draft.phases[1].volumeMultiplier == 1.0)
        #expect(draft.phases[1].intensityMultiplier == 0.85)

        #expect(draft.phases[2].kind == .deload)
        #expect(draft.phases[2].weeks == 1)
        #expect(draft.phases[2].volumeMultiplier == 0.5)
        #expect(draft.phases[2].intensityMultiplier == 0.60)
    }

    // 260610-hcv: at 390–393pt the phase card's fixed chrome (badge, stat trio,
    // chevron, ⋮⋮ handle) left the title too little width, so "Intensification"
    // ended in "…". Render the real builder and read every card back with OCR.
    @MainActor
    @Test("Phase card titles and subtitles render in full on 390–402pt iPhones")
    func phaseCardTextRendersInFullOnNarrowPhones() async throws {
        let expectedText = [
            "Accumulation", "BUILD VOLUME",
            "Intensification", "BUILD STRENGTH",
            "Peak", "SHARPEN OUTPUT",
            "Realization", "TEST MAXES",
            "Deload", "RECOVER",
        ]
        for width in [390.0, 393.0, 402.0] {
            let lines = try await recognizedText(inBuilderOfWidth: width)
            for text in expectedText {
                #expect(lines.contains { $0.contains(text) },
                        "\"\(text)\" is cut off at \(Int(width))pt. Read: \(lines)")
            }
        }
    }

    /// Hosts BlockBuilderView with one card per phase kind in a window `width` points
    /// wide (tall enough that every card is on screen) and returns the lines Vision reads.
    @MainActor
    private func recognizedText(inBuilderOfWidth width: CGFloat) async throws -> [String] {
        let draft = BlockDraft.newBlock()
        draft.phases = BlockPhaseKind.allCases.map {
            BlockPhaseDraft(kind: $0, weeks: 1, volumeMultiplier: 1.0, intensityMultiplier: 0.8)
        }
        let host = UIHostingController(
            rootView: BlockBuilderView(draft: draft)
                .modelContainer(PreviewModelContainer.make(seedFixture: false))
        )
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 1900)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .seconds(1))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds, format: format).image { _ in
            _ = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: try #require(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
