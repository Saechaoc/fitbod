---
phase: quick-261004-m1
plan: 01
subsystem: DesignSystem / App shell / Library / Routines / Sessions / History
status: complete
tags: [design-system, chalkline, swiftui, persistence, rest-timer, xcuitest, ci]
provides:
  - "Chalkline tokens + components + component gallery (fitbod/DesignSystem)"
  - "Five-tab shell (Today, Routines, Library, History, Settings) with AppRouter and a full-screen workout cover that auto-resumes on launch"
  - "Persisted absolute-deadline rest timer (RestTimerPersistence) restored at launch"
  - "WorkoutLogic: validation, add/delete sets, previous performance (excludes the workout in progress), finish pruning, stats, recap"
  - "ExerciseStore (custom exercise delete with explicit nullify), upsert catalog importer"
  - "XCUITest journey with terminate/relaunch + layout audit; CI workflow on macOS runners"
key-files:
  created:
    - fitbod/DesignSystem/*
    - fitbod/App/{AppRouter,LaunchConfiguration,TodayView,DemoData}.swift
    - fitbod/History/HistoryView.swift
    - fitbod/Sessions/{WorkoutLogic,WorkoutLauncher,WorkoutSummaryView}.swift
    - fitbod/Sessions/RestTimer/RestTimerPersistence.swift
    - fitbod/Routines/RoutineDetailView.swift
    - fitbod/ExerciseLibrary/{ExerciseStore,ExerciseHistorySummary}.swift
    - fitbodTests/{RestTimerPersistence,WorkoutLogic,WorkoutPersistence,ExerciseStoreAndDemoData}Tests.swift
    - fitbodUITests/{WorkoutJourney,LayoutAudit}UITests.swift
    - .github/workflows/ios.yml, scripts/ci/*
    - docs/**
  removed:
    - Sessions/{PreviousColumn,InlineRPEChipRow,DecimalRPEPickerSheet,SetTypeChip,PrescriptionWeightCell,WarmupRampRows,AddUnplannedExerciseButton,ResumeWorkoutBanner}.swift
    - Routines/InlineExerciseSearchRow.swift, ExerciseLibrary/FilterChip.swift, App/PlaceholderTabView.swift
decisions:
  - "No SwiftData schema changes in this milestone (versioned schemas share live classes; migration risk on the developer's store)."
  - "Exercise delete nullifies references explicitly (ExerciseStore) instead of adding an inverse relationship."
  - "Rest timer state lives in UserDefaults (ephemeral UI state, no migration), keyed rest-timer.snapshot.v1."
  - "Catalog re-seed is an in-place upsert by externalID; the previous wipe-and-reimport would have orphaned routines and history."
  - "Native verification runs on GitHub-hosted macOS runners; evidence is committed back on [evidence] commits."
---

# Milestone 1 summary

See `docs/verification.md` for build/test evidence and `docs/roadmap.md` for
what is next.
