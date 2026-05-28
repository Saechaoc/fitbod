//
//  ProgramViewFidelityTests.swift
//  fitbodTests
//
//  Source-level guardrails for the Program empty-state fidelity pass.
//  These tests intentionally check structure and local metrics, not pixel
//  snapshots; the final visual pass still relies on simulator screenshots.
//

import Foundation
import Testing

@Suite("ProgramView fidelity")
struct ProgramViewFidelityTests {

    private static func projectPath(_ components: [String]) -> URL {
        components.reduce(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        ) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func source(_ components: String...) throws -> String {
        try String(contentsOf: Self.projectPath(components), encoding: .utf8)
    }

    private func codeOnly(_ components: String...) throws -> String {
        try String(contentsOf: Self.projectPath(components), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("ProgramView uses compact mockup chrome instead of generic section chrome")
    func programViewUsesCompactMockupChrome() throws {
        let source = try source("fitbod", "Periodization", "ProgramView.swift")
        let codeOnly = try codeOnly("fitbod", "Periodization", "ProgramView.swift")

        #expect(source.contains("ProgramChromeHeader"),
                "ProgramView should use a dedicated top chrome that can draw through the top safe area.")
        #expect(source.contains("ProgramTemplateHeader"),
                "Program templates need a compact header matching the PNG, not the taller generic BRUSectionHead.")
        #expect(!codeOnly.contains("BRUSectionHead("),
                "ProgramView's template header should not use BRUSectionHead because its 45pt height is too tall for the mockup.")
        #expect(!codeOnly.contains(#"Text("setup")"#),
                "The fake mockup 'setup' status label must not render inside the production Program screen.")
        #expect(!codeOnly.contains("statusBandHeight"),
                "ProgramChromeHeader should start at the app header after safe-area normalization, not reserve fake status chrome.")
    }

    @Test("BRUTabBar carries mockup-specific tab metrics")
    func bruTabBarCarriesMockupMetrics() throws {
        let source = try source("fitbod", "Design", "BRUTabBar.swift")

        #expect(source.contains("mockupCellHeight"),
                "BRUTabBar should expose a named mockup cell-height constant for the Program-screen nav fidelity pass.")
        #expect(source.contains("mockupBottomSafeOverlap"),
                "BRUTabBar should account for the mockup's bar extending into the bottom safe area.")
    }

    @Test("NoProgramHero pins the mockup headline scale and vertical rhythm")
    func noProgramHeroPinsMockupHeadlineMetrics() throws {
        let source = try source("fitbod", "Periodization", "ProgramView.swift")

        #expect(source.contains("ProgramScreenTokens"),
                "The Program screen should centralize fixed measured layout tokens.")
        #expect(source.contains("static let noProgramFontSize: CGFloat = 68"),
                "NO PROGRAM should use the measured Bebas Neue scale from the 393pt mockup viewport.")
        #expect(source.contains("static let heroTopPadding: CGFloat = 20"),
                "Hero caption should start on the normalized mockup Y grid while preserving the headline/body grid.")
        #expect(source.contains("static let captionToHeadlineSpacing: CGFloat = 0"),
                "ACTIVE BLOCK and NO PROGRAM should have the measured visual gap; a negative spacing collapses the caption into the headline.")
        #expect(source.contains("static let bodyLineHeight: CGFloat = 20"),
                "The body paragraph should pin line height instead of using default SwiftUI text metrics.")
        #expect(source.contains("static let ctaHeight: CGFloat = 71"),
                "The CTA should use the measured 71pt button height from the PNG.")
        #expect(source.contains("static let templateRowHeight: CGFloat = 77"),
                "Template rows should use the measured row content height so separator-to-separator spacing matches the PNG.")
    }

    @Test("ProgramView registers and uses mockup fonts")
    func programViewRegistersAndUsesMockupFonts() throws {
        let programSource = try source("fitbod", "Periodization", "ProgramView.swift")
        let infoPlist = try source("fitbod", "Info.plist")

        #expect(infoPlist.contains("BebasNeue-Regular.ttf"),
                "Bebas Neue must be registered in UIAppFonts for Program display typography.")
        #expect(infoPlist.contains("Geist-Regular.ttf"),
                "Geist must be registered in UIAppFonts for Program body typography.")
        #expect(programSource.contains(#".custom("BebasNeue-Regular""#),
                "NO PROGRAM, week labels, CTA, and uppercase labels should use Bebas Neue.")
        #expect(programSource.contains(#".custom("Geist-Regular""#),
                "Program body copy and row titles should use Geist.")
        #expect(!programSource.contains(".width(.compressed)"),
                "Program fidelity should use the mockup display font, not compressed system fallback.")
    }

    @Test("ProgramView pins exact mockup copy")
    func programViewPinsExactMockupCopy() throws {
        let source = try source("fitbod", "Periodization", "ProgramView.swift")

        #expect(source.contains("+ DEFINE BLOCK ▶"),
                "CTA text should be exactly '+ DEFINE BLOCK ▶' as one centered label.")
        #expect(source.contains(#"ProgramFeatureChip(label: "WEEKS · 4-12")"#))
        #expect(source.contains(#"ProgramFeatureChip(label: "PHASES · 1-4")"#))
        #expect(source.contains(#"ProgramFeatureChip(label: "DELOAD OPTIONAL")"#))
        #expect(source.contains(#"ProgramFeatureChip(label: "CUSTOM")"#))
        #expect(source.contains("A block schedules routines across weeks and phases — "))
        #expect(source.contains("accumulation, intensification, peak, deload."))
        #expect(source.contains("You can also lift without a block, but Fitbod really earns its keep when you’re running one."))
    }

    @Test("ProgramView + NEW opens reusable BRU action popover with block and routine routes")
    func programNewUsesBRUActionPopover() throws {
        let programSource = try source("fitbod", "Periodization", "ProgramView.swift")
        let popoverURL = Self.projectPath(["fitbod", "Design", "BRUActionPopover.swift"])

        #expect(FileManager.default.fileExists(atPath: popoverURL.path),
                "The custom + NEW menu should live in a reusable BRUActionPopover primitive.")

        if FileManager.default.fileExists(atPath: popoverURL.path) {
            let popoverSource = try String(contentsOf: popoverURL, encoding: .utf8)
            #expect(popoverSource.contains("public struct BRUActionPopover"),
                    "The reusable action popover should be available to future BRU menus.")
            #expect(popoverSource.contains("struct BRUActionPopoverItem"),
                    "Popover rows should be data-driven instead of hard-coded inside ProgramView.")
            #expect(popoverSource.contains("static let rowHeight: CGFloat = 40"),
                    "The two-row popover should match the compact New-modal reference height.")
        }

        #expect(programSource.contains("@State private var showingNewPopover = false"),
                "ProgramView should own a boolean for the anchored + NEW popover.")
        #expect(programSource.contains("@State private var presentingNewRoutine = false"),
                "ProgramView should present the routine builder from the popover's routine row.")
        #expect(programSource.contains("ProgramChromeHeader(onNew: { showingNewPopover = true })"),
                "Tapping + NEW should open the custom popover instead of immediately starting a block.")
        #expect(programSource.contains("BRUActionPopover("),
                "ProgramView should render the reusable BRUActionPopover overlay.")
        #expect(programSource.contains(#"title: "+ New block""#),
                "The first popover row should match the supplied New-modal copy.")
        #expect(programSource.contains(#"title: "+ New routine""#),
                "The second popover row should match the supplied New-modal copy.")
        #expect(programSource.contains("startBlank()"),
                "The New block action opens the start-choice sheet.")
        #expect(programSource.contains("presentingNewRoutine = true"),
                "The New routine action should route directly to RoutineBuilderView.")
        #expect(programSource.contains("RoutineBuilderView(draft: RoutineDraft())"),
                "ProgramView should present the existing routine builder for New routine.")
        #expect(programSource.contains("Create New Block"),
                "The start-choice sheet should be titled 'Create New Block'.")
        #expect(programSource.contains("How do you want to start?"),
                "The start-choice sheet should prompt 'How do you want to start?'.")
    }
}
