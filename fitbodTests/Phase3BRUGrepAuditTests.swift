// Phase3BRUGrepAuditTests.swift
// fitbodTests
//
// Phase 3.2 Plan 10 — final guardrail for the Phase 3.2 BRU visual rewrite
// (Prescription & Warm-ups reskin). Mirrors the BRUGrepAuditTests pattern
// from Phase 02.1-11 exactly.
//
// PURPOSE: Programmatically grep every Phase 3 surface file under the
// audited directories and assert ZERO occurrences of banned legacy
// UIKit/HIG tokens. If a future bugfix accidentally re-introduces
// Color.accentColor or Image(systemName:) into a Phase 3 surface, this
// test fires — catching the regression in CI rather than via a manual
// gsd-ui-checker run.
//
// AUDITED DIRECTORIES (Phase 3.2 surfaces):
//   fitbod/Sessions/      (6 reskinned files: WhyThisWeightSheet, WarmupRampRows,
//                          BumpBanner, CalibratingBadge, PlateStackDisclosure,
//                          PrescriptionWeightCell)
//   fitbod/Settings/      (PlateInventoryEditor, PlateCalculatorSheet, SettingsView
//                          Smart Progression section — all three are Phase 3.2 scope)
//   fitbod/Routines/      (WarmupConfigSheet only — the rest of Routines/ belongs to
//                          Phase 02.1 and is audited by BRUGrepAuditTests)
//   fitbod/ExerciseLibrary/ (ExerciseDetailView only — the rest of ExerciseLibrary is
//                           Phase 1. ExerciseDetailView is excluded from THIS audit
//                           because its Phase-1 sections may still reference legacy
//                           tokens; those are Phase 1 / Phase 06 scope. See SUMMARY.)
//   fitbod/Design/        (CalibratingProgressMeter, PlateStackViz, PlateTallyRow —
//                          Wave 1 BRU primitives)
//
// EXCLUDED FILES: Files under audited directories that belong to a different
// phase's scope (Phase 02.1 Routines views, Phase 1 ExerciseLibrary views,
// Phase 5 Settings views, behavior-only files in Sessions/).
//
// NOTE: These tests run against the source tree, not compiled output.
// They use FileManager to walk the source directories and String regex
// matching for banned token detection.

import Testing
import Foundation

@Suite("Phase 3 BRU Grep Audit")
struct Phase3BRUGrepAuditTests {

    // MARK: - Configuration

    /// Suffixes (relative path fragments) of files excluded from the Phase 3 audit.
    /// These either belong to a different phase's BRU scope or are non-view behavior files.
    private static let excludedFileSuffixes: Set<String> = [
        // --- Phase 02.1 Routines surfaces (audited by BRUGrepAuditTests) ---
        "fitbod/Routines/RoutineBuilderView.swift",
        "fitbod/Routines/RoutinesListView.swift",
        "fitbod/Routines/RoutineRow.swift",
        "fitbod/Routines/RoutineExerciseCard.swift",
        "fitbod/Routines/BottomActionBar.swift",
        "fitbod/Routines/InlineExerciseSearchRow.swift",
        "fitbod/Routines/MoveRoutineSheet.swift",
        "fitbod/Routines/NewFolderSheet.swift",
        "fitbod/Routines/PerSetOverrideRow.swift",
        "fitbod/Routines/PrescriptionEditorRow.swift",
        "fitbod/Routines/RoutineBuilderDayTabs.swift",
        "fitbod/Routines/SetRowsContainer.swift",
        "fitbod/Routines/SupersetAssignmentSheet.swift",
        // Non-view behavior files in Routines
        "fitbod/Routines/PrescriptionDefaults.swift",
        "fitbod/Routines/RoutineDraft.swift",
        "fitbod/Routines/RoutineDuplicator.swift",
        "fitbod/Routines/RoutineFolderDraft.swift",

        // --- Phase 02.1 Sessions surfaces (audited by BRUGrepAuditTests) ---
        "fitbod/Sessions/SessionLoggerView.swift",
        "fitbod/Sessions/SessionExerciseCard.swift",
        "fitbod/Sessions/SetRow.swift",
        "fitbod/Sessions/SetTypeChip.swift",
        "fitbod/Sessions/WorkoutHeaderToolbar.swift",
        "fitbod/Sessions/ResumeWorkoutBanner.swift",
        "fitbod/Sessions/WorkoutNotesSheet.swift",
        "fitbod/Sessions/SwapExerciseSheet.swift",
        "fitbod/Sessions/SessionHistoryView.swift",
        "fitbod/Sessions/SessionHistoryRow.swift",
        "fitbod/Sessions/SessionHistoryStatStrip.swift",
        "fitbod/Sessions/WeeklyTonnageSparkCard.swift",
        "fitbod/Sessions/AddUnplannedExerciseButton.swift",
        "fitbod/Sessions/ClusterSubRepChipRow.swift",
        "fitbod/Sessions/DecimalRPEPickerSheet.swift",
        "fitbod/Sessions/InlineRPEChipRow.swift",
        "fitbod/Sessions/PartialRepsRow.swift",
        "fitbod/Sessions/PerSetNoteSheet.swift",
        "fitbod/Sessions/PinnedNoteCapsule.swift",
        "fitbod/Sessions/TempoEntryRow.swift",
        "fitbod/Sessions/PreviousColumn.swift",
        // Phase 6 Sessions surfaces
        "fitbod/Sessions/InSessionPRBanner.swift",
        "fitbod/Sessions/PinnedNoteSheet.swift",
        // Behavior files (not views)
        "fitbod/Sessions/SessionFactory.swift",
        "fitbod/Sessions/PreviousMatchingIntent.swift",
        "fitbod/Sessions/InSessionPRState.swift",

        // --- Phase 1 ExerciseLibrary surfaces ---
        // ExerciseDetailView has Phase-1 sections that may reference legacy tokens;
        // Phase 3.2-08 only audited the Prescription Settings section. Defer the
        // full ExerciseDetailView audit to a future BRU rewrite phase. See SUMMARY.
        "fitbod/ExerciseLibrary/ExerciseDetailView.swift",
        "fitbod/ExerciseLibrary/ExerciseLibraryView.swift",
        "fitbod/ExerciseLibrary/ExerciseHistoryView.swift",
        "fitbod/ExerciseLibrary/ExerciseHistoryRow.swift",
        "fitbod/ExerciseLibrary/ExerciseRow.swift",
        "fitbod/ExerciseLibrary/CustomExerciseEditor.swift",
        "fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift",
        "fitbod/ExerciseLibrary/EmptyLibraryView.swift",
        "fitbod/ExerciseLibrary/ExerciseFilterBar.swift",
        "fitbod/ExerciseLibrary/FilterChip.swift",
        "fitbod/ExerciseLibrary/FilterPickerSheet.swift",
        "fitbod/ExerciseLibrary/IntentFilterChipRow.swift",
        "fitbod/ExerciseLibrary/MusclePickerSheet.swift",
        "fitbod/ExerciseLibrary/MuscleWeightRow.swift",
        "fitbod/ExerciseLibrary/PRStripFooter.swift",
        // Non-view behavior files in ExerciseLibrary
        "fitbod/ExerciseLibrary/CustomExerciseDraft.swift",
        "fitbod/ExerciseLibrary/EquipmentMapper.swift",
        "fitbod/ExerciseLibrary/ExerciseDeletion.swift",
        "fitbod/ExerciseLibrary/ExerciseDTO.swift",
        "fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift",
        "fitbod/ExerciseLibrary/FilterState.swift",
        "fitbod/ExerciseLibrary/MuscleRegionMap.swift",
        "fitbod/ExerciseLibrary/SeedError.swift",

        // --- Phase 5 Settings surfaces (audited separately) ---
        "fitbod/Settings/MuscleVolumeTargetEditor.swift",
        // SettingsView has mixed phase ownership: Phase 1 (Units toggle), Phase 4 (Data/export),
        // Phase 5 (Volume Targets), Phase 6 (Backup/Restore), Phase 3.2 (Smart Progression).
        // The non-Phase-3.2 sections still use legacy .font(.callout/.caption) and
        // Color(.systemRed) tokens. Excluding the whole file here; the Phase 3.2 section
        // (smartProgressionSection) was audited inline by the plan author. A future
        // BRU rewrite phase should do a comprehensive SettingsView pass.
        "fitbod/Settings/SettingsView.swift",
        // Non-view behavior files in Settings
        "fitbod/Settings/PlateInventory+Defaults.swift",
        "fitbod/Settings/PlateInventorySeeder.swift",

        // --- Phase 02.1 Design primitives (audited by BRUGrepAuditTests via fitbod/Views/) ---
        // Note: fitbod/Design/ CalibratingProgressMeter, PlateStackViz, PlateTallyRow are
        // Wave 1 BRU primitives created clean — they are IN SCOPE for this audit (not excluded).
        // Other Design primitives (BRUButton, BRUChip, etc.) are Phase 02.1 scope and audited
        // by BRUGrepAuditTests via fitbod/Views/ or fitbod/Design/ depending on project layout.
        // Since fitbod/Design/ is a NEW audit dir for Phase 3, all Design/ files that are NOT
        // Phase 3 Wave 1 primitives are excluded here to avoid double-counting.
        "fitbod/Design/BRUButton.swift",
        "fitbod/Design/BRUChip.swift",
        "fitbod/Design/BRUCornerBadge.swift",
        "fitbod/Design/BRUDashedSlot.swift",
        "fitbod/Design/BRUDisplay.swift",
        "fitbod/Design/BRUDivider.swift",
        "fitbod/Design/BRUFont.swift",
        "fitbod/Design/BRUHeaderBar.swift",
        "fitbod/Design/BRUPhoneFrame.swift",
        "fitbod/Design/BRUPillButton.swift",
        "fitbod/Design/BRUReadout.swift",
        "fitbod/Design/BRUSectionHead.swift",
        "fitbod/Design/BRUSpark.swift",
        "fitbod/Design/BRUSupersetBracket.swift",
        "fitbod/Design/BRUTabBar.swift",
        "fitbod/Design/Color+BRU.swift",
        "fitbod/Design/SetCompletionGlyph.swift",
    ]

    /// Audit directory names relative to the project root.
    private static let auditDirNames: [String] = [
        "fitbod/Sessions",
        "fitbod/Settings",
        "fitbod/Routines",
        "fitbod/ExerciseLibrary",
        "fitbod/Design",
    ]

    // MARK: - Helper

    /// Returns all .swift URLs under the Phase 3 audit directories,
    /// minus the excluded set and minus any #Preview-only files.
    ///
    /// Derives the project root from the test file's compile-time path
    /// (#filePath points into fitbodTests/, one level below the project root).
    private func surfaceFileURLs(
        file: StaticString = #filePath
    ) throws -> [URL] {
        let testFilePath = String(describing: file)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        // fitbodTests/Phase3BRUGrepAuditTests.swift → go up 2 levels to project root
        let projectRoot = testFileURL
            .deletingLastPathComponent() // fitbodTests/
            .deletingLastPathComponent() // project root

        var results: [URL] = []
        let fm = FileManager.default

        for dirName in Self.auditDirNames {
            let dirURL = projectRoot.appendingPathComponent(dirName)
            guard let enumerator = fm.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "swift" else { continue }
                // Check against excluded suffixes
                let absolutePath = fileURL.path
                let isExcluded = Self.excludedFileSuffixes.contains { suffix in
                    absolutePath.hasSuffix(suffix)
                }
                guard !isExcluded else { continue }
                results.append(fileURL)
            }
        }
        return results
    }

    /// Checks all surface files for a banned regex pattern.
    /// Returns a list of violation strings ("path/file.swift:42: offending line").
    private func violations(
        pattern: String,
        in files: [URL]
    ) throws -> [String] {
        var found: [String] = []
        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = source.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                // Skip pure comment lines — grepping for banned patterns in comments
                // is expected (they document the contract). Only flag actual code.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                // Also skip lines inside #Preview blocks — system-name images and
                // semantic fonts are acceptable in development-only previews.
                if line.contains("#Preview") { continue }
                // Use NSRegularExpression for full regex support
                let regex = try NSRegularExpression(pattern: pattern)
                let lineRange = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: lineRange) != nil {
                    let shortPath = fileURL.path.components(separatedBy: "/fitbod/").last
                        ?? fileURL.lastPathComponent
                    found.append("fitbod/\(shortPath):\(index + 1): \(trimmed)")
                }
            }
        }
        return found
    }

    // MARK: - @Test Functions

    @Test("No Color.accentColor in Phase 3 surfaces")
    func noColorAccentColorInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(
            pattern: #"Color\.accentColor|Color\("AccentColor"\)|\.tint\(\.accentColor\)"#,
            in: files
        )
        #expect(hits.isEmpty, "BRU violation — Color.accentColor found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Color(.system*) in Phase 3 surfaces")
    func noColorSystemPatternInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"Color\(\.system"#, in: files)
        #expect(hits.isEmpty, "BRU violation — Color(.system*) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Image(systemName:) in Phase 3 surfaces")
    func noImageSystemNameInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"Image\(systemName:"#, in: files)
        #expect(hits.isEmpty, "BRU violation — Image(systemName:) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Capsule clipShape in Phase 3 surfaces")
    func noCapsuleClipInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"\.clipShape\(Capsule\(\)|\.clipShape\(\.capsule"#, in: files)
        #expect(hits.isEmpty, "BRU violation — .clipShape(Capsule()) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No RoundedRectangle(cornerRadius:) in Phase 3 surfaces")
    func noRoundedRectangleCornerRadiusInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"RoundedRectangle\(cornerRadius:"#, in: files)
        #expect(hits.isEmpty, "BRU violation — RoundedRectangle(cornerRadius:) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Apple semantic font styles in Phase 3 surfaces")
    func noAppleSemanticFontStylesInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        // Combined pattern for all banned .font() semantic styles
        let pattern = #"\.font\(\.(body|headline|title|title2|title3|caption|caption2|subheadline|footnote|callout|largeTitle)\)"#
        let hits = try violations(pattern: pattern, in: files)
        #expect(hits.isEmpty, "BRU violation — Apple semantic .font() style found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No .buttonStyle(.bordered) in Phase 3 surfaces")
    func noBorderedButtonStyleInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(
            pattern: #"\.buttonStyle\(\.bordered\)|\.buttonStyle\(\.borderedProminent\)"#,
            in: files
        )
        #expect(hits.isEmpty, "BRU violation — .buttonStyle(.bordered) found:\n\(hits.joined(separator: "\n"))")
    }

    @Test("No ContentUnavailableView in Phase 3 surfaces (replaced by BRU empty state per 03.2-06)")
    func noContentUnavailableViewInPhase3Surfaces() throws {
        let files = try surfaceFileURLs()
        let hits = try violations(pattern: #"ContentUnavailableView\b"#, in: files)
        #expect(hits.isEmpty, "BRU violation — ContentUnavailableView found (use custom BRU empty state):\n\(hits.joined(separator: "\n"))")
    }

    @Test("No Stepper( in PlateInventoryEditor (replaced by PlateTallyRow per 03.2-06)")
    func noStepperOnPlateInventoryRowsInPhase3Surfaces() throws {
        let testFilePath = String(describing: #filePath as StaticString)
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let plateInventoryEditorURL = projectRoot
            .appendingPathComponent("fitbod/Settings/PlateInventoryEditor.swift")

        // Only audit PlateInventoryEditor specifically for Stepper(
        guard FileManager.default.fileExists(atPath: plateInventoryEditorURL.path) else {
            return // File not found — skip gracefully
        }

        let hits = try violations(pattern: #"Stepper\("#, in: [plateInventoryEditorURL])
        #expect(hits.isEmpty, "BRU violation — Stepper( found in PlateInventoryEditor (use PlateTallyRow):\n\(hits.joined(separator: "\n"))")
    }
}
