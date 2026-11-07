//
//  ExportSnapshot.swift
//  fitbod
//
//  The one model-to-DTO snapshot behind the JSON export
//  (`ExportService`), the `.fitbodbackup` archive (`BackupArchiver`) and
//  the backup round-trip tests. Each `@ModelActor` passes its own
//  `ModelContext`, so no model crosses an actor boundary.
//
//  Every entity is fetched sorted by id (sessions by startedAt) so the
//  output is stable between runs. Image bytes are not part of the
//  document; the backup archive carries them as `images/<uuid>.jpg`.
//

import Foundation
import SwiftData

enum ExportSnapshot {

    /// Every entity in `context`, mapped to its DTO.
    static func document(in context: ModelContext, exportedAt: Date) throws -> ExportDocument {
        let userSettings = try context.fetch(FetchDescriptor<UserSettings>()).first.map(mapUserSettings)
        return ExportDocument(
            formatVersion: 2,
            schemaVersion: ExportDocument.canonicalSchemaVersion,
            exportedAt: exportedAt,
            unitSystem: userSettings?.unitsRaw ?? WeightUnit.default.rawValue,
            exercises: try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.id)])).map(mapExercise),
            routines: try context.fetch(FetchDescriptor<SessionTemplate>(sortBy: [SortDescriptor(\.id)])).map(mapRoutine),
            splits: try context.fetch(FetchDescriptor<Split>(sortBy: [SortDescriptor(\.id)])).map(mapSplit),
            routineFolders: try context.fetch(FetchDescriptor<RoutineFolder>(sortBy: [SortDescriptor(\.id)])).map(mapRoutineFolder),
            supersetGroups: try context.fetch(FetchDescriptor<SupersetGroup>(sortBy: [SortDescriptor(\.id)])).map(mapSupersetGroup),
            sessions: try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)])).map(mapSession),
            blocks: try context.fetch(FetchDescriptor<Block>(sortBy: [SortDescriptor(\.id)])).map(mapBlock),
            muscleGroups: try context.fetch(FetchDescriptor<MuscleGroup>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleGroup),
            exerciseMuscleStimuli: try context.fetch(FetchDescriptor<ExerciseMuscleStimulus>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleStimulus),
            muscleVolumeTargets: try context.fetch(FetchDescriptor<MuscleVolumeTarget>(sortBy: [SortDescriptor(\.id)])).map(mapMuscleVolumeTarget),
            plateInventories: try context.fetch(FetchDescriptor<PlateInventory>(sortBy: [SortDescriptor(\.id)])).map(mapPlateInventory),
            userSettings: userSettings
        )
    }

    // MARK: - Mappers (model → DTO)

    private static func mapSplit(_ split: Split) -> ExportSplitDTO {
        let slots = (split.slots ?? []).sorted { $0.position < $1.position }.map {
            ExportSplitSessionSlotDTO(id: $0.id, position: $0.position, sessionTemplateID: $0.sessionTemplate?.id)
        }
        return ExportSplitDTO(
            id: split.id, name: split.name, createdAt: split.createdAt,
            isArchived: split.isArchived, slots: slots
        )
    }

    private static func mapExercise(_ ex: Exercise) -> ExportExerciseDTO {
        ExportExerciseDTO(
            id: ex.id,
            externalID: ex.externalID,
            name: ex.name,
            canonicalName: ex.canonicalName,
            equipmentRaw: ex.equipmentRaw,
            mechanicRaw: ex.mechanicRaw,
            forceRaw: ex.forceRaw,
            levelRaw: ex.levelRaw,
            patternRaw: ex.patternRaw,
            category: ex.category,
            instructions: ex.instructions,
            imagePaths: ex.imagePaths,
            isCustom: ex.isCustom,
            primaryMuscleSlugsJoined: ex.primaryMuscleSlugsJoined,
            createdAt: ex.createdAt,
            smallestIncrement: ex.smallestIncrement,
            barWeightOverride: ex.barWeightOverride,
            unitOverrideRaw: ex.unitOverrideRaw,
            plateauWindowOverride: ex.plateauWindowOverride,
            plateauToleranceOverride: ex.plateauToleranceOverride
        )
    }

    private static func mapMuscleGroup(_ m: MuscleGroup) -> ExportMuscleGroupDTO {
        ExportMuscleGroupDTO(
            id: m.id, slug: m.slug,
            displayName: m.displayName, regionRaw: m.regionRaw
        )
    }

    private static func mapMuscleStimulus(_ s: ExerciseMuscleStimulus) -> ExportExerciseMuscleStimulusDTO {
        ExportExerciseMuscleStimulusDTO(
            id: s.id,
            exerciseID: s.exercise?.id,
            muscleID: s.muscle?.id,
            role: s.role, weight: s.weight,
            userEditedWeight: s.userEditedWeight
        )
    }

    private static func mapRoutineFolder(_ f: RoutineFolder) -> ExportRoutineFolderDTO {
        ExportRoutineFolderDTO(
            id: f.id, name: f.name,
            sortOrder: f.sortOrder, createdAt: f.createdAt
        )
    }

    private static func mapSupersetGroup(_ s: SupersetGroup) -> ExportSupersetGroupDTO {
        ExportSupersetGroupDTO(
            id: s.id, routineID: s.routineID,
            kindRaw: s.kindRaw, sortOrder: s.sortOrder,
            createdAt: s.createdAt
        )
    }

    private static func mapRoutine(_ r: SessionTemplate) -> ExportRoutineDTO {
        let exercises = (r.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapRoutineExercise($0) }
        return ExportRoutineDTO(
            id: r.id, name: r.name, notes: r.notes,
            createdAt: r.createdAt, updatedAt: r.updatedAt,
            isArchived: r.isArchived,
            blockID: r.block?.id,
            folderID: r.folderID,
            intentRaw: r.intentRaw,
            progressionKindRaw: r.progressionKindRaw,
            exercises: exercises
        )
    }

    private static func mapRoutineExercise(_ re: SessionExerciseTemplate) -> ExportRoutineExerciseDTO {
        let overrides = (re.setOverrides ?? [])
            .sorted { $0.setIndex < $1.setIndex }
            .map { mapSetOverride($0) }
        return ExportRoutineExerciseDTO(
            id: re.id,
            exerciseID: re.exercise?.id,
            orderIndex: re.orderIndex,
            targetSets: re.targetSets,
            targetRepsLow: re.targetRepsLow,
            targetRepsHigh: re.targetRepsHigh,
            targetRPE: re.targetRPE,
            targetRIR: re.targetRIR,
            prescribedRestSeconds: re.prescribedRestSeconds,
            tempo: re.tempo,
            notes: re.notes,
            generateWarmups: re.generateWarmups,
            supersetGroupID: re.supersetGroupID,
            tracksTempo: re.tracksTempo,
            tracksPartialReps: re.tracksPartialReps,
            warmupOverrideData: re.warmupOverrideData,
            setOverrides: overrides
        )
    }

    private static func mapSetOverride(_ s: RoutineExerciseSetOverride) -> ExportRoutineExerciseSetOverrideDTO {
        ExportRoutineExerciseSetOverrideDTO(
            id: s.id, setIndex: s.setIndex,
            targetRepsLow: s.targetRepsLow,
            targetRepsHigh: s.targetRepsHigh,
            targetRPE: s.targetRPE
        )
    }

    private static func mapSession(_ s: Session) -> ExportSessionDTO {
        let exercises = (s.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapSessionExercise($0) }
        return ExportSessionDTO(
            id: s.id, startedAt: s.startedAt,
            completedAt: s.completedAt,
            routineSnapshotName: s.routineSnapshotName,
            sourceRoutineID: s.sourceRoutineID,
            blockID: s.block?.id,
            notes: s.notes,
            totalDurationSeconds: s.totalDurationSeconds,
            intentRaw: s.intentRaw,
            progressionKindRaw: s.progressionKindRaw,
            templateName: s.templateName,
            slotPosition: s.slot?.position,
            slotSplitName: s.slot?.split?.name,
            slotID: s.slot?.id,
            exercises: exercises
        )
    }

    private static func mapSessionExercise(_ se: SessionExercise) -> ExportSessionExerciseDTO {
        let sets = (se.sets ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapSetEntry($0) }
        return ExportSessionExerciseDTO(
            id: se.id,
            exerciseID: se.exercise?.id,
            exerciseName: se.displayName,
            orderIndex: se.orderIndex,
            targetSets: se.targetSets,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            targetRIR: se.targetRIR,
            prescribedRestSeconds: se.prescribedRestSeconds,
            tempo: se.tempo,
            tracksTempo: se.tracksTempo,
            tracksPartialReps: se.tracksPartialReps,
            prescribedWeight: se.prescribedWeight,
            pinnedNote: se.pinnedNote,
            exerciseNameSnapshot: se.exerciseNameSnapshot,
            sets: sets
        )
    }

    private static func mapSetEntry(_ e: SetEntry) -> ExportSetEntryDTO {
        ExportSetEntryDTO(
            id: e.id, orderIndex: e.orderIndex,
            weight: e.weight, reps: e.reps,
            rpe: e.rpe, rir: e.rir,
            restAfterSeconds: e.restAfterSeconds,
            tempoActual: e.tempoActual,
            notes: e.notes, isWarmup: e.isWarmup,
            setTypeRaw: e.setTypeRaw,
            completedAt: e.completedAt,
            partialReps: e.partialReps,
            clusterSubRepsJoined: e.clusterSubRepsJoined,
            isComplete: e.isComplete,
            wasManualOverride: e.wasManualOverride
        )
    }

    private static func mapBlock(_ b: Block) -> ExportBlockDTO {
        let phases = (b.phases ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { mapBlockPhase($0) }
        return ExportBlockDTO(
            id: b.id, name: b.name,
            startDate: b.startDate, endDate: b.endDate,
            notes: b.notes, isActive: b.isActive,
            reviewedAt: b.reviewedAt,
            schedulingModeRaw: b.schedulingModeRaw,
            trainingDaysJoined: b.trainingDaysJoined,
            archivedConfigJSON: b.archivedConfigJSON,
            splitName: b.split?.name,
            splitID: b.split?.id,
            phases: phases
        )
    }

    private static func mapBlockPhase(_ p: BlockPhase) -> ExportBlockPhaseDTO {
        ExportBlockPhaseDTO(
            id: p.id, orderIndex: p.orderIndex,
            nameRaw: p.nameRaw, weeks: p.weeks,
            volumeMultiplier: p.volumeMultiplier,
            intensityMultiplier: p.intensityMultiplier,
            notes: p.notes
        )
    }

    private static func mapMuscleVolumeTarget(_ t: MuscleVolumeTarget) -> ExportMuscleVolumeTargetDTO {
        ExportMuscleVolumeTargetDTO(
            id: t.id, muscleID: t.muscle?.id,
            mv: t.mv, mev: t.mev, mav: t.mav, mrv: t.mrv,
            notes: t.notes, userEdited: t.userEdited
        )
    }

    private static func mapPlateInventory(_ pi: PlateInventory) -> ExportPlateInventoryDTO {
        ExportPlateInventoryDTO(
            id: pi.id, equipmentKindRaw: pi.equipmentKindRaw,
            barWeight: pi.barWeight,
            availablePlatesData: pi.availablePlatesData,
            createdAt: pi.createdAt, updatedAt: pi.updatedAt
        )
    }

    private static func mapUserSettings(_ s: UserSettings) -> ExportUserSettingsDTO {
        ExportUserSettingsDTO(
            id: s.id, unitsRaw: s.unitsRaw,
            defaultProgressionKindRaw: s.defaultProgressionKindRaw,
            warmupSchemeRaw: s.warmupSchemeRaw,
            customWarmupPercents: s.customWarmupPercents,
            plateauWindowSessions: s.plateauWindowSessions,
            plateauTolerance: s.plateauTolerance,
            deloadAlertEnabled: s.deloadAlertEnabled,
            weekStartsMonday: s.weekStartsMonday,
            defaultIncrementKg: s.defaultIncrementKg,
            minCalibrationSets: s.minCalibrationSets,
            frequencyHitMinSets: s.frequencyHitMinSets,
            deloadAdvisoryDismissedWeekStart: s.deloadAdvisoryDismissedWeekStart,
            weeklyRecapShownForWeekStart: s.weeklyRecapShownForWeekStart
        )
    }
}
