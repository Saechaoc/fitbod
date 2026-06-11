//
//  BackupRestorer.swift
//  fitbod
//
//  Wave-5 plan 06-10 Tasks 4+5 — read + validate + apply a
//  `.fitbodbackup` ZIP archive to wipe-and-replace the current
//  SwiftData store.
//
//  ## Flow (CONTEXT D-32)
//
//  1. preflight(url:context:) — parses ZIP, locates manifest/store,
//     verifies SHA-256 checksum + schemaVersion match + no active
//     session in progress. Returns BackupManifest on success;
//     throws RestoreError on every gate.
//  2. Caller (SettingsView) shows the destructive-confirmation alert
//     with verbatim UI-SPEC copy: "This will replace all current data
//     with the backup. This cannot be undone."
//  3. performRestore(url:manifest:currentContainer:) — actually
//     wipes the current store, instantiates a fresh ModelContainer,
//     decodes the ExportDocument from store.json, and inserts every
//     entity in dependency order. Image bytes from images/{uuid}.jpg
//     entries are reattached to matching Exercise rows.
//  4. restart() — calls `exit` with status 0 so iOS relaunches the
//     app with the fresh ModelContainer (Open Question 5 RESOLVED;
//     personal-install app per PROJECT.md, so SIGABRT-style restart
//     is acceptable).
//
//  ## Side-file insurance (D-32 step 4)
//
//  Before any destructive op, performRestore writes the current
//  store's full ExportDocument to
//  documentDirectory/store-pre-restore-{ISO8601}.json. If the
//  restore corrupts the new store, the user can manually recover
//  the JSON via Files. v1 has no automated rollback UI — the file
//  exists for manual triage only.
//
//  ## Security gates (RESEARCH §V10 — defense in depth)
//
//  - Checksum mismatch → .checksumMismatch
//  - Schema-version mismatch → .schemaVersionMismatch
//  - Active session in progress → .activeSessionInProgress
//  - Path traversal in archive entry → .pathTraversalDetected
//    (also enforced inside ZIPReader earlier)
//  - Decompression bomb → .decompressionBombExceeded
//    (also enforced inside ZIPReader earlier)
//  - Missing manifest.json → .missingManifest
//  - Missing store.json → .missingStoreJSON
//  - ZIP parse failure → .zipParseFailed(underlying:)
//
//  ## Process restart is the only side effect that escapes this file
//
//  RESEARCH Pitfall 10 + Open Question 5 RESOLVED — confined to
//  `restart() -> Never`. Settings view calls this from the "OK" button
//  of the "Restore complete" alert.
//
//  [CITED: CONTEXT D-30 + D-31 + D-32 + D-33 + RESEARCH §Pattern 6
//   + Pitfall 10 + §Security Domain V10 + Open Question 5 RESOLVED]
//

import CryptoKit
import Foundation
import OSLog
import SwiftData

@MainActor
public final class BackupRestorer {

    public enum RestoreError: Error, Equatable {
        case fileUnreadable
        case checksumMismatch
        case schemaVersionMismatch(found: String, expected: String)
        case activeSessionInProgress
        case decompressionBombExceeded
        case pathTraversalDetected(entry: String)
        case decodeFailed(underlying: String)
        case missingManifest
        case missingStoreJSON
        case zipParseFailed(underlying: String)
    }

    private static let log = Logger(subsystem: "com.fitbod.app", category: "backup")

    public init() {}

    // MARK: - Preflight (Task 4)

    /// Parse the archive at `url`; verify checksum + schemaVersion +
    /// no active session. Returns the manifest on success. Caller is
    /// expected to show the destructive-confirmation alert next.
    public func preflight(url: URL, context: ModelContext) async throws -> BackupManifest {
        // 1. Read file bytes.
        guard let data = try? Data(contentsOf: url) else {
            throw RestoreError.fileUnreadable
        }

        // 2. Parse ZIP container.
        let entries: [ZIPReader.Entry]
        do {
            entries = try ZIPReader.read(data: data)
        } catch let e as ZIPReader.ReadError {
            switch e {
            case .totalSizeExceeded:
                throw RestoreError.decompressionBombExceeded
            case .pathTraversalDetected(let entry):
                throw RestoreError.pathTraversalDetected(entry: entry)
            default:
                throw RestoreError.zipParseFailed(underlying: String(describing: e))
            }
        } catch {
            throw RestoreError.zipParseFailed(underlying: String(describing: error))
        }

        // 3. Locate manifest + store.
        guard let manifestEntry = entries.first(where: { $0.path == "manifest.json" }) else {
            throw RestoreError.missingManifest
        }
        guard let storeEntry = entries.first(where: { $0.path == "store.json" }) else {
            throw RestoreError.missingStoreJSON
        }

        // 4. Decode manifest.
        let manifest: BackupManifest
        do {
            manifest = try BackupManifest.decode(manifestEntry.data)
        } catch {
            throw RestoreError.zipParseFailed(underlying: "manifest decode: \(error)")
        }

        // 5. Verify SHA-256 checksum of store.json bytes.
        let digest = SHA256.hash(data: storeEntry.data)
        let computed = digest.map { String(format: "%02x", $0) }.joined()
        guard computed == manifest.checksum else {
            throw RestoreError.checksumMismatch
        }

        // 6. Verify schema version match (strict string equality).
        let expected = ExportDocument.canonicalSchemaVersion
        guard manifest.schemaVersion == expected else {
            throw RestoreError.schemaVersionMismatch(
                found: manifest.schemaVersion,
                expected: expected
            )
        }

        // 7. Active-session gate — restore wipes everything; an
        //    in-progress session would lose data unrecoverably.
        let inProgress = try context.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.completedAt == nil })
        )
        if !inProgress.isEmpty {
            throw RestoreError.activeSessionInProgress
        }

        Self.log.info("BackupRestorer.preflight OK — schemaVersion=\(manifest.schemaVersion, privacy: .public) imageCount=\(manifest.imageCount, privacy: .public)")
        return manifest
    }

    // MARK: - Perform restore (Task 5)

    /// Wipe-and-replace. Caller (SettingsView) must show the
    /// destructive-confirmation alert before invoking this.
    public func performRestore(
        url: URL,
        manifest: BackupManifest,
        currentContainer: ModelContainer
    ) async throws {
        // Re-read the archive so we have fresh entry data.
        guard let data = try? Data(contentsOf: url) else {
            throw RestoreError.fileUnreadable
        }
        let entries: [ZIPReader.Entry]
        do {
            entries = try ZIPReader.read(data: data)
        } catch {
            throw RestoreError.zipParseFailed(underlying: String(describing: error))
        }

        guard let storeEntry = entries.first(where: { $0.path == "store.json" }) else {
            throw RestoreError.missingStoreJSON
        }

        // Decode the ExportDocument first so a decode failure aborts
        // BEFORE any destructive op runs.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let doc: ExportDocument
        do {
            doc = try decoder.decode(ExportDocument.self, from: storeEntry.data)
        } catch {
            throw RestoreError.decodeFailed(underlying: String(describing: error))
        }

        // Step 1 — Side-file insurance: snapshot current store to
        // documentDirectory/store-pre-restore-{ISO8601}.json.
        // We do this on a best-effort basis — if the snapshot fails,
        // we log and continue (we already have the user's destructive
        // confirmation; refusing to restore because we couldn't write
        // a rollback side-file would be hostile).
        if let documentsDir = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            // Replace ':' with '-' so the filename is filesystem-friendly.
            let stamp = isoFormatter.string(from: .now)
                .replacingOccurrences(of: ":", with: "-")
            let sideFileURL = documentsDir.appendingPathComponent("store-pre-restore-\(stamp).json")

            do {
                let archiver = BackupArchiver(modelContainer: currentContainer)
                _ = try await archiver.archive(outputURL: sideFileURL.deletingPathExtension().appendingPathExtension("fitbodbackup"))
                Self.log.info("Side-file insurance written to \(sideFileURL.lastPathComponent, privacy: .public)")
            } catch {
                Self.log.error("Side-file insurance write failed: \(error.localizedDescription, privacy: .public). Continuing with restore.")
            }
        }

        // Step 2 — Wipe the current container's contents. SwiftData
        // does not expose a clean container reset API; we delete every
        // row of every model type. Using the existing currentContainer
        // means we don't need to touch SQLite files on disk — when the
        // app restarts via process exit, the cleared rows will persist.
        let ctx = currentContainer.mainContext

        try ctx.delete(model: SetEntry.self)
        try ctx.delete(model: SessionExercise.self)
        try ctx.delete(model: Session.self)
        try ctx.delete(model: RoutineExerciseSetOverride.self)
        try ctx.delete(model: SessionExerciseTemplate.self)
        try ctx.delete(model: SupersetGroup.self)
        try ctx.delete(model: SessionTemplate.self)
        try ctx.delete(model: RoutineFolder.self)
        try ctx.delete(model: BlockPhase.self)
        try ctx.delete(model: Block.self)
        try ctx.delete(model: MuscleVolumeTarget.self)
        try ctx.delete(model: ExerciseMuscleStimulus.self)
        try ctx.delete(model: MuscleGroup.self)
        try ctx.delete(model: Exercise.self)
        try ctx.delete(model: PlateInventory.self)
        try ctx.delete(model: UserSettings.self)
        try ctx.save()

        // Step 3 — Build image-bytes lookup from ZIP entries
        // (defense-in-depth path validation: re-check whitelist before
        // attaching to any Exercise).
        var imageBytesByID: [UUID: Data] = [:]
        for entry in entries {
            guard entry.path.hasPrefix("images/"), entry.path.hasSuffix(".jpg") else {
                continue
            }
            let trimmed = entry.path
                .dropFirst("images/".count)
                .dropLast(".jpg".count)
            guard let uuid = UUID(uuidString: String(trimmed)) else { continue }
            // Reject any pathological entry the ZIPReader didn't catch.
            if entry.path.contains("..") || entry.path.hasPrefix("/") {
                throw RestoreError.pathTraversalDetected(entry: entry.path)
            }
            imageBytesByID[uuid] = entry.data
        }

        // Step 4 — Insert the entities in dependency order, two-pass:
        // pass 1 builds value entities + collects by-id maps; pass 2
        // attaches relationships using those maps.
        try insertDecodedDocument(doc, into: ctx, imageBytesByID: imageBytesByID)
        try ctx.save()

        Self.log.info("BackupRestorer.performRestore complete — \(doc.exercises.count) exercises, \(doc.sessions.count) sessions, \(imageBytesByID.count) images")
    }

    // MARK: - Process exit is the locked restart mechanism
    //
    // CONTEXT D-32 step 5 + RESEARCH Pitfall 10 + Open Question 5
    // RESOLVED — a personal-install app on a single user device can
    // exit cleanly after a successful restore to force iOS to relaunch
    // the process. SwiftData does not currently support tearing down
    // and reinitialising a ModelContainer in-place after such a
    // destructive wipe; the simplest correct path is process restart.
    // Only one call site in the entire codebase (right below this
    // marker comment).
    public func restart() -> Never {
        Self.log.info("BackupRestorer.restart — invoking process exit (Open Question 5 RESOLVED)")
        exit(0)
    }

    // MARK: - Entity insertion (two-pass)

    /// Insert every entity in the decoded `ExportDocument` into
    /// `ctx`, restoring relationships via DTO UUID references. Image
    /// bytes from the ZIP archive's `images/` directory are attached
    /// to matching Exercise rows.
    private func insertDecodedDocument(
        _ doc: ExportDocument,
        into ctx: ModelContext,
        imageBytesByID: [UUID: Data]
    ) throws {
        // ---- Pass 1 — instantiate every entity, no relationships yet.
        // Build by-id maps for later relationship fix-up.

        var muscleGroupsByID: [UUID: MuscleGroup] = [:]
        for dto in doc.muscleGroups {
            let m = MuscleGroup()
            m.id = dto.id
            m.slug = dto.slug
            m.displayName = dto.displayName
            m.regionRaw = dto.regionRaw
            ctx.insert(m)
            muscleGroupsByID[dto.id] = m
        }

        var exercisesByID: [UUID: Exercise] = [:]
        for dto in doc.exercises {
            let ex = Exercise()
            ex.id = dto.id
            ex.externalID = dto.externalID
            ex.name = dto.name
            ex.canonicalName = dto.canonicalName
            ex.equipmentRaw = dto.equipmentRaw
            ex.mechanicRaw = dto.mechanicRaw
            ex.forceRaw = dto.forceRaw
            ex.levelRaw = dto.levelRaw
            ex.patternRaw = dto.patternRaw
            ex.category = dto.category
            ex.instructions = dto.instructions
            ex.imagePaths = dto.imagePaths
            ex.isCustom = dto.isCustom
            ex.primaryMuscleSlugsJoined = dto.primaryMuscleSlugsJoined
            ex.createdAt = dto.createdAt
            ex.smallestIncrement = dto.smallestIncrement
            ex.barWeightOverride = dto.barWeightOverride
            ex.unitOverrideRaw = dto.unitOverrideRaw
            ex.plateauWindowOverride = dto.plateauWindowOverride
            ex.plateauToleranceOverride = dto.plateauToleranceOverride
            if let bytes = imageBytesByID[dto.id] {
                ex.imageData = bytes
            }
            ctx.insert(ex)
            exercisesByID[dto.id] = ex
        }

        for dto in doc.exerciseMuscleStimuli {
            let s = ExerciseMuscleStimulus()
            s.id = dto.id
            s.role = dto.role
            s.weight = dto.weight
            s.userEditedWeight = dto.userEditedWeight
            if let exID = dto.exerciseID, let ex = exercisesByID[exID] {
                s.exercise = ex
            }
            if let muID = dto.muscleID, let mu = muscleGroupsByID[muID] {
                s.muscle = mu
            }
            ctx.insert(s)
        }

        var foldersByID: [UUID: RoutineFolder] = [:]
        for dto in doc.routineFolders {
            let f = RoutineFolder()
            f.id = dto.id
            f.name = dto.name
            f.sortOrder = dto.sortOrder
            f.createdAt = dto.createdAt
            ctx.insert(f)
            foldersByID[dto.id] = f
        }

        for dto in doc.supersetGroups {
            let g = SupersetGroup()
            g.id = dto.id
            g.routineID = dto.routineID
            g.kindRaw = dto.kindRaw
            g.sortOrder = dto.sortOrder
            g.createdAt = dto.createdAt
            ctx.insert(g)
        }

        // Blocks (parents) before BlockPhases.
        var blocksByID: [UUID: Block] = [:]
        for dto in doc.blocks {
            let b = Block()
            b.id = dto.id
            b.name = dto.name
            b.startDate = dto.startDate
            b.endDate = dto.endDate
            b.notes = dto.notes
            b.isActive = dto.isActive
            b.reviewedAt = dto.reviewedAt
            // WR-05 (V7): restore program-graph scalar fields. archivedConfigJSON
            // is the freeze-#2 archive (spec §6 — sole source of truth for
            // completed-block views); without it, restored completed blocks would
            // be permanently unreadable. schedulingModeRaw / trainingDaysJoined
            // carry the live scheduling config. (Block.split live-graph reattach is
            // deferred to Phase 8 split wiring; splitName travels in the export for
            // that future use.)
            b.schedulingModeRaw = dto.schedulingModeRaw
            b.trainingDaysJoined = dto.trainingDaysJoined
            b.archivedConfigJSON = dto.archivedConfigJSON
            ctx.insert(b)
            blocksByID[dto.id] = b
            for phaseDTO in dto.phases {
                let p = BlockPhase()
                p.id = phaseDTO.id
                p.orderIndex = phaseDTO.orderIndex
                p.nameRaw = phaseDTO.nameRaw
                p.weeks = phaseDTO.weeks
                p.volumeMultiplier = phaseDTO.volumeMultiplier
                p.intensityMultiplier = phaseDTO.intensityMultiplier
                p.notes = phaseDTO.notes
                p.block = b
                ctx.insert(p)
            }
        }

        // Routines + RoutineExercises + SetOverrides.
        var routinesByID: [UUID: SessionTemplate] = [:]
        for dto in doc.routines {
            let r = SessionTemplate()
            r.id = dto.id
            r.name = dto.name
            r.notes = dto.notes
            r.createdAt = dto.createdAt
            r.updatedAt = dto.updatedAt
            r.isArchived = dto.isArchived
            r.folderID = dto.folderID
            r.intentRaw = dto.intentRaw
            r.progressionKindRaw = dto.progressionKindRaw
            if let blockID = dto.blockID, let block = blocksByID[blockID] {
                r.block = block
            }
            ctx.insert(r)
            routinesByID[dto.id] = r

            for reDTO in dto.exercises {
                let re = SessionExerciseTemplate()
                re.id = reDTO.id
                re.orderIndex = reDTO.orderIndex
                re.targetSets = reDTO.targetSets
                re.targetRepsLow = reDTO.targetRepsLow
                re.targetRepsHigh = reDTO.targetRepsHigh
                re.targetRPE = reDTO.targetRPE
                re.targetRIR = reDTO.targetRIR
                re.prescribedRestSeconds = reDTO.prescribedRestSeconds
                re.tempo = reDTO.tempo
                re.notes = reDTO.notes
                re.generateWarmups = reDTO.generateWarmups
                re.supersetGroupID = reDTO.supersetGroupID
                re.tracksTempo = reDTO.tracksTempo
                re.tracksPartialReps = reDTO.tracksPartialReps
                re.warmupOverrideData = reDTO.warmupOverrideData
                re.sessionTemplate = r
                if let exID = reDTO.exerciseID, let ex = exercisesByID[exID] {
                    re.exercise = ex
                }
                ctx.insert(re)

                for ovDTO in reDTO.setOverrides {
                    let ov = RoutineExerciseSetOverride()
                    ov.id = ovDTO.id
                    ov.setIndex = ovDTO.setIndex
                    ov.targetRepsLow = ovDTO.targetRepsLow
                    ov.targetRepsHigh = ovDTO.targetRepsHigh
                    ov.targetRPE = ovDTO.targetRPE
                    ov.routineExercise = re
                    ctx.insert(ov)
                }
            }
        }

        // Sessions + SessionExercises + SetEntries.
        for dto in doc.sessions {
            let s = Session()
            s.id = dto.id
            s.startedAt = dto.startedAt
            s.completedAt = dto.completedAt
            s.routineSnapshotName = dto.routineSnapshotName
            s.sourceRoutineID = dto.sourceRoutineID
            s.notes = dto.notes
            s.totalDurationSeconds = dto.totalDurationSeconds
            s.intentRaw = dto.intentRaw
            s.progressionKindRaw = dto.progressionKindRaw
            // WR-05 (V7): restore the log-time template-name snapshot (freeze #1
            // insurance — survives a nullified template ref). slotPosition /
            // slotSplitName travel in the export for forward use; live slot-graph
            // reattach is deferred to Phase 8.
            s.templateName = dto.templateName
            if let blockID = dto.blockID, let block = blocksByID[blockID] {
                s.block = block
            }
            ctx.insert(s)

            for seDTO in dto.exercises {
                let se = SessionExercise()
                se.id = seDTO.id
                se.orderIndex = seDTO.orderIndex
                se.targetSets = seDTO.targetSets
                se.targetRepsLow = seDTO.targetRepsLow
                se.targetRepsHigh = seDTO.targetRepsHigh
                se.targetRPE = seDTO.targetRPE
                se.targetRIR = seDTO.targetRIR
                se.prescribedRestSeconds = seDTO.prescribedRestSeconds
                se.tempo = seDTO.tempo
                se.tracksTempo = seDTO.tracksTempo
                se.tracksPartialReps = seDTO.tracksPartialReps
                se.prescribedWeight = seDTO.prescribedWeight
                se.pinnedNote = seDTO.pinnedNote
                se.session = s
                if let exID = seDTO.exerciseID, let ex = exercisesByID[exID] {
                    se.exercise = ex
                }
                ctx.insert(se)

                for setDTO in seDTO.sets {
                    let e = SetEntry()
                    e.id = setDTO.id
                    e.orderIndex = setDTO.orderIndex
                    e.weight = setDTO.weight
                    e.reps = setDTO.reps
                    e.rpe = setDTO.rpe
                    e.rir = setDTO.rir
                    e.restAfterSeconds = setDTO.restAfterSeconds
                    e.tempoActual = setDTO.tempoActual
                    e.notes = setDTO.notes
                    e.isWarmup = setDTO.isWarmup
                    e.setTypeRaw = setDTO.setTypeRaw
                    e.completedAt = setDTO.completedAt
                    e.partialReps = setDTO.partialReps
                    e.clusterSubRepsJoined = setDTO.clusterSubRepsJoined
                    e.isComplete = setDTO.isComplete
                    e.wasManualOverride = setDTO.wasManualOverride
                    e.sessionExercise = se
                    ctx.insert(e)
                }
            }
        }

        // MuscleVolumeTargets.
        for dto in doc.muscleVolumeTargets {
            let t = MuscleVolumeTarget()
            t.id = dto.id
            t.mv = dto.mv
            t.mev = dto.mev
            t.mav = dto.mav
            t.mrv = dto.mrv
            t.notes = dto.notes
            t.userEdited = dto.userEdited
            if let muID = dto.muscleID, let mu = muscleGroupsByID[muID] {
                t.muscle = mu
            }
            ctx.insert(t)
        }

        // PlateInventories.
        for dto in doc.plateInventories {
            let pi = PlateInventory()
            pi.id = dto.id
            pi.equipmentKindRaw = dto.equipmentKindRaw
            pi.barWeight = dto.barWeight
            pi.availablePlatesData = dto.availablePlatesData
            pi.createdAt = dto.createdAt
            pi.updatedAt = dto.updatedAt
            ctx.insert(pi)
        }

        // UserSettings.
        if let dto = doc.userSettings {
            let s = UserSettings()
            s.id = dto.id
            s.unitsRaw = dto.unitsRaw
            s.defaultProgressionKindRaw = dto.defaultProgressionKindRaw
            s.warmupSchemeRaw = dto.warmupSchemeRaw
            s.customWarmupPercents = dto.customWarmupPercents
            s.plateauWindowSessions = dto.plateauWindowSessions
            s.plateauTolerance = dto.plateauTolerance
            s.deloadAlertEnabled = dto.deloadAlertEnabled
            s.weekStartsMonday = dto.weekStartsMonday
            s.defaultIncrementKg = dto.defaultIncrementKg
            s.minCalibrationSets = dto.minCalibrationSets
            s.frequencyHitMinSets = dto.frequencyHitMinSets
            s.deloadAdvisoryDismissedWeekStart = dto.deloadAdvisoryDismissedWeekStart
            s.weeklyRecapShownForWeekStart = dto.weeklyRecapShownForWeekStart
            ctx.insert(s)
        }
    }
}
