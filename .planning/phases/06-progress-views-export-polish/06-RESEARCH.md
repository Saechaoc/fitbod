# Phase 6: Progress Views, Export & Polish - Research

**Researched:** 2026-05-22
**Domain:** Swift Charts visualization, e1RM math, PR detection, RFC-4180/JSON export, ZIP backup/restore, ShareLink/Transferable
**Confidence:** HIGH on Apple-native APIs (SwiftUI, SwiftData, Swift Charts, Swift Testing, CryptoKit, AppleArchive, ShareLink/Transferable, fileImporter, UTType) and on the e1RM formula identities. MEDIUM on `AppleArchive` vs. raw-ZIP tradeoffs for `.fitbodbackup`. LOW on exact Swift Charts performance ceilings (Apple has not published numeric guarantees; figures here are community-derived).

> Context7 MCP and the `ctx7` CLI fallback were both unavailable in this session — Apple-doc claims are therefore tagged `[CITED]` against canonical doc URLs the planner can verify on macOS during execution rather than `[VERIFIED]`. All non-Apple recommendations are tagged `[ASSUMED]`.

## Summary

Phase 6 is **pure presentation polish on top of a stable Phase 1/2 backend** — no new persistent fields, no new schema version. Every chart, PR computation, and export DTO is a pure function or `Codable` value type over the existing `Session → SessionExercise → SetEntry` cascade. The only new SwiftData affordance is one additive `#Index` on `SetEntry` to make per-exercise/per-intent time-series queries cheap.

The phase splits cleanly into three independent vertical slices the planner can wave-parallelize:

1. **Math kernel** — `OneRepMax`, `PRDetector`, `WeeklyTonnageAggregator`, `SessionComparator`, `MuscleVolumeProvider` (protocol). Pure value-type Swift, no `ModelContainer` needed for unit tests. Locked behind Swift Testing parameterized `@Test`s.
2. **Chart + PR surfaces** — `ProgressHomeView` (tab root), `ExerciseProgressView`, `ExercisePRsView`, `WeeklyTonnageView`, `SessionComparisonView`, `InSessionPRBanner` (overlays `SessionLoggerView`). All bind directly to `@Query<SetEntry>`/`@Query<Session>` with tight predicates — never wrap a `@Query` in a view-model (FOUND-06).
3. **Export + backup** — `CSVFile`/`JSONFile` `Transferable` value types, `BackupWriter` (manifest + store.json + images → ZIP via `AppleArchive` or `Compression`), `BackupReader` (verify + decode + repopulate ModelContainer), `.fileImporter` UI surface. The round-trip Swift Testing acceptance suite (D-33) is the gating test for EXP-03/EXP-04.

**Primary recommendation:** Wave the phase into (1) math kernel + e1RM/PR services (Wave 1, all-pure-function) → (2) chart surfaces + PR banner integration into `SessionLoggerView` (Wave 2) → (3) CSV/JSON Transferable + Settings Data section (Wave 3) → (4) backup/restore + round-trip acceptance suite (Wave 4). Math-first means every visual phase has tested foundations underneath.

> **CRITICAL schema-name reality check before planning:** CONTEXT.md (auto-generated) repeatedly refers to `SetEntry.actualWeight / actualReps / actualRPE / performedAt` and `SetEntry.setKind`. The **actual SchemaV2 field names are `weight: Double` / `reps: Int` / `rpe: Double?` / `completedAt: Date` and `setTypeRaw: String` (with `isWarmup: Bool` + computed `setType` accessor).** The planner MUST use the real schema names — see §"Schema reality vs CONTEXT" below. This is a documentation drift in CONTEXT.md, not a missing field — no migration is needed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Per-exercise progress chart | SwiftUI View (`@Query<SetEntry>` direct) | Pure math kernel (`OneRepMax.estimate`) | Reactive `@Query` drives Swift Charts; transformation is a stateless map. FOUND-06: no view-model wrapper. |
| e1RM math | Pure Swift kernel (`OneRepMax` enum/struct) | — | Stateless; no SwiftData dependency. Unit-testable in `fitbodTests/` without a ModelContainer. |
| PR table | In-memory `@Observable PRTable` owned by `SessionLoggerView` `@State` | SwiftData `@Query<SetEntry>` filtered at session start | Computed-on-demand at session start; lives in session ephemeral state until session ends. D-12 explicit. |
| Live PR detection | Pure function `PRDetector.check(set:against:) -> Set<PRKind>` | `@Observable` banner state | Pure on set commit. Banner is presentation-only. |
| Weekly tonnage aggregation | Pure function `WeeklyTonnageAggregator.aggregate(_: [SetEntry], by: TonnageSliceMode)` | `@Query<SetEntry>` upstream | All math in a value type for testability. |
| Muscle-stack aggregation | Protocol `MuscleVolumeProvider` (Phase-6 default + Phase-5 swap) | `ExerciseMuscleStimulus` reads | Protocol abstracts the Phase 5 dependency: Phase 6 ships `UnweightedMuscleVolumeProvider` now; Phase 5 ships `StimulusWeightedMuscleVolumeProvider` later. |
| Session comparison match | Pure function over `[Session]` (passed from `@Query`) | `Predicate<Session>` keyed on `sourceRoutineID` | Match is one-shot at view appear; no SwiftData inside the kernel. |
| CSV export | `Transferable` value type `CSVFile` | `RFC4180Encoder` static function | Lazy render in the `Transferable` `DataRepresentation`; off-main-thread on `Task.detached`. |
| JSON export | `Transferable` value type `JSONFile` | DTO graph (`ExportDocument`) + `JSONEncoder` | Codable DTOs decouple export shape from SwiftData internals (D-28). |
| Backup write (.fitbodbackup) | `BackupWriter` actor (off-main) | `AppleArchive` framework (preferred) OR raw ZIP writer (fallback) | Off-main because images can be tens of MB. UTI declaration in Info.plist. |
| Backup restore | `BackupReader` actor + `.fileImporter` SwiftUI modifier | `ModelContainer` reset via SQLite-file delete | Two-step destructive confirm; side-file rollback insurance. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Swift Charts | iOS 17+ SDK (no SPM) | All chart rendering (LineMark/PointMark/BarMark/RuleMark/AreaMark) | Project locked: PROJECT.md "Charting Decision" forbids DGCharts. `[CITED: developer.apple.com/documentation/Charts]` |
| SwiftData | iOS 18+ SDK | `@Query`/`@Model` reactive persistence | Locked by project. `#Index` available for hot query paths (iOS 18). `[CITED: developer.apple.com/xcode/swiftdata]` |
| SwiftUI | iOS 18+ SDK | All views; `ShareLink`, `.fileImporter`, `Transferable` integration | Locked. `[CITED: developer.apple.com/documentation/SwiftUI]` |
| Swift Testing | Xcode 16+ | Unit tests for OneRepMax/PRDetector/Aggregators/Comparator/Encoders/BackupRoundTrip | Project standard for new tests. `@Test`, `#expect`, parameterized via `arguments:`. `[CITED: developer.apple.com/documentation/Testing]` |
| Foundation `Transferable` | iOS 16+ | `ShareLink(item:)` payloads for CSV/JSON/backup | Standard 2025-2026 share pattern. `[CITED: developer.apple.com/documentation/CoreTransferable/Transferable]` |
| CryptoKit | iOS 13+ | SHA-256 of `store.json` for backup `manifest.json.checksum` | Native, no dependency. `[CITED: developer.apple.com/documentation/cryptokit/sha256]` |
| AppleArchive | iOS 14+ (`AppleArchive` framework) | Recommended container for `.fitbodbackup` (LZFSE inside an `aar` envelope, or a true ZIP via the lower-level `ArchiveStream`) | Native Apple API, simpler than hand-rolling a ZIP central-directory writer. `[CITED: developer.apple.com/documentation/applearchive]` |
| Compression | iOS 9+ (`Compression` framework) | Fallback if AppleArchive shape doesn't fit (e.g. you need raw ZIP for cross-platform interchange) | Native, low-level. `[CITED: developer.apple.com/documentation/compression]` |
| UniformTypeIdentifiers | iOS 14+ | `UTType.fitbodBackup` declaration + `.fileImporter(allowedContentTypes:)` | Standard UTI surface for custom doc types. `[CITED: developer.apple.com/documentation/uniformtypeidentifiers]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `Date.ISO8601FormatStyle` (Foundation) | iOS 15+ | ISO-8601 UTC timestamps in CSV + JSON | Use `.iso8601(timeZone: .gmt)` — NOT the legacy `ISO8601DateFormatter` class. `[CITED: developer.apple.com/documentation/foundation/iso8601formatstyle]` |
| `JSONEncoder` (.prettyPrinted + .sortedKeys + .iso8601) | iOS 8+ | JSON export envelope | `JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]`; `dateEncodingStrategy = .iso8601`. `[CITED: developer.apple.com/documentation/foundation/jsonencoder]` |
| `UINotificationFeedbackGenerator` (UIKit) | iOS 10+ | PR banner haptic (`.success`) | Standard haptic surface; pre-prepare with `.prepare()` to reduce latency. `[CITED: developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator]` |
| `UISelectionFeedbackGenerator` (UIKit) | iOS 10+ | Chart series toggle chips (`.selectionChanged` via `selectionChanged()` method) | Subtle haptic for chip toggles per D-35. |
| `FileManager.urls(for: .documentDirectory, in: .userDomainMask)` | iOS 2+ | Staging directory for exports + side-file backup before restore | Standard. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| Swift Charts | Custom `Canvas` rendering | Only for muscle silhouette heatmap (Phase 5, not 6). Phase 6 charts are conventional bars/lines/points — Swift Charts is correct. |
| AppleArchive | Hand-rolled ZIP (PKZIP central directory writer) | Raw ZIP is ~150 LOC + edge cases (UTF-8 file names, ZIP64 for large blobs, CRC32). AppleArchive's `.aar` is simpler and produces a valid Apple-recognized container; the UTI declaration tells `.fileImporter` to accept either. Recommend AppleArchive primary, raw-ZIP fallback only if cross-platform interchange becomes a requirement (out of v1 scope per CONTEXT.md "Deferred Ideas"). |
| `Transferable` `FileRepresentation` | `ProxyRepresentation` (string) | `FileRepresentation` is correct for files — Files app respects the UTI and filename; `ProxyRepresentation` would paste text into Messages but break file-quality share. |
| In-memory `String` build of CSV | Streamed `OutputStream` | At realistic v1 scale (single user, <100K sets ever), a single `String` build is fine (~5-10 MB worst case). Streamed pattern is a profile-driven future optimization. |
| Brzycki/Epley formulas | Other 1RM formulas (Mayhew, Lombardi, O'Conner, Wathen) | CONTEXT D-04 explicitly locks Brzycki+Epley. No deviation. |
| `JSONEncoder` with default key order | `.sortedKeys` | `.sortedKeys` is the diff-friendly choice for a backup-versioning use case (text-diffable across exports). D-28 explicit. |

**Installation:**

No new packages. Everything is Apple-native and bundled in the iOS 18 SDK.

**Version verification:**

```bash
# No SPM packages added in this phase — version check N/A.
xcodebuild -showsdks | grep iphoneos
```

## Package Legitimacy Audit

Not applicable. **Phase 6 adds zero third-party packages.** All capabilities are satisfied by Apple-native frameworks already in the iOS 18 SDK. CLAUDE.md "Third-party SPM dependencies" is explicitly "Locked out — entire stack is Apple-native (SwiftData, SwiftUI, Swift Charts, Swift Testing)."

| Package | Registry | Disposition |
|---|---|---|
| (none) | — | No external installs — section retained for protocol completeness. |

## Architecture Patterns

### System Architecture Diagram

```
                  ┌─────────────────────────────────────────────┐
                  │           SwiftData store (SchemaV2)         │
                  │                                              │
                  │   Session → SessionExercise → SetEntry       │
                  │                       ↑                      │
                  │                 (read-only)                  │
                  └─────────────────────┬────────────────────────┘
                                        │
        ┌───────────────────────────────┼────────────────────────────────┐
        │ @Query<…> reactive reads      │                                │
        ▼                               ▼                                ▼
┌──────────────┐               ┌──────────────────┐         ┌───────────────────┐
│ Math kernel  │               │ Chart surfaces   │         │ Export pipeline   │
│ (pure value  │ ◄──────────── │ (SwiftUI Views)  │         │ (Transferable +   │
│  types)      │ used by ──┐   │                  │         │  BackupWriter)    │
│              │           │   │ ExerciseProgress │         │                   │
│ OneRepMax    │           │   │ ExercisePRs      │         │ CSVFile           │
│ PRDetector   │           │   │ WeeklyTonnage    │         │ JSONFile          │
│ TonnageAgg   │           │   │ SessionCompare   │         │ BackupWriter      │
│ Comparator   │           │   │ ProgressHome     │         │ BackupReader      │
│ MuscleVolume │           │   │                  │         │                   │
│ Provider     │           │   │ InSessionPR      │         └─────────┬─────────┘
│ (protocol)   │           │   │ Banner (overlay  │                   │
└──────┬───────┘           │   │ on SessionLogger)│                   ▼
       │                   │   └────────┬─────────┘         ┌───────────────────┐
       │                   │            │                   │  ShareLink /      │
       │                   │            ▼                   │  .fileImporter    │
       │                   │   ┌──────────────────┐         │  (Files /         │
       │                   └───┤ Swift Charts     │         │   iCloud Drive /  │
       │                       │ (Bar/Line/Point/ │         │   AirDrop)        │
       │                       │  Rule/Area Mark) │         └───────────────────┘
       │                       └──────────────────┘
       │
       ▼
┌──────────────────────────┐
│ Swift Testing suites     │
│  - OneRepMaxTests        │
│  - PRDetectorTests       │
│  - WeeklyTonnageTests    │
│  - SessionComparatorTests│
│  - ExportEncoderTests    │
│  - BackupRoundTripTests  │
└──────────────────────────┘
```

### Recommended Project Structure

```
fitbod/
├── Progress/                       # NEW — Phase 6 chart surfaces
│   ├── ProgressHomeView.swift      # Tab root: per-exercise card list + Weekly Tonnage entry + PRs entry
│   ├── ExerciseProgressView.swift  # Per-exercise intent-split chart (PROG-01..03)
│   ├── ExercisePRsView.swift       # Per-exercise PR table (PROG-05)
│   ├── WeeklyTonnageView.swift     # Weekly tonnage chart with slicers (PROG-04)
│   ├── SessionComparisonView.swift # This-week vs last-week diff (PROG-07)
│   ├── InSessionPRBanner.swift     # Overlay on SessionLoggerView (PROG-08)
│   ├── ChartFilterState.swift      # @Observable filter state for tonnage chart
│   └── ProgressColors.swift        # Accent token reuse (Phase 1 palette)
├── Math/                            # NEW — pure-value kernels
│   ├── OneRepMax.swift             # Brzycki/Epley estimator (PROG-02)
│   ├── PRDetector.swift            # PR table + check(set:) detector (PROG-05/08)
│   ├── WeeklyTonnageAggregator.swift
│   ├── SessionComparator.swift
│   └── MuscleVolumeProvider.swift  # Protocol + UnweightedMuscleVolumeProvider default
├── Export/                          # NEW — data export pipeline
│   ├── DTOs/
│   │   ├── ExportDocument.swift    # Top-level envelope (formatVersion, schemaVersion, …)
│   │   ├── ExerciseDTO.swift       # (Note: collides with existing seed DTO at ExerciseLibrary/ExerciseDTO.swift — rename one)
│   │   ├── RoutineDTO.swift
│   │   ├── SessionDTO.swift
│   │   └── …
│   ├── CSVFile.swift               # Transferable for CSV
│   ├── CSVEncoder.swift            # RFC 4180 writer
│   ├── JSONFile.swift              # Transferable for JSON
│   └── ExportService.swift         # Off-main async render
├── Backup/                          # NEW — backup/restore pipeline
│   ├── BackupWriter.swift          # Actor — composes manifest+store.json+images, archives
│   ├── BackupReader.swift          # Actor — verifies checksum + schemaVersion, decodes
│   ├── BackupManifest.swift        # Codable manifest DTO
│   ├── BackupArchive.swift         # AppleArchive (or raw ZIP) read/write
│   └── UTType+FitbodBackup.swift   # UTType.fitbodBackup declaration
├── Settings/
│   └── SettingsView.swift          # MODIFIED — add Data section (Export CSV / JSON / Create backup / Restore)
└── Sessions/
    └── SessionLoggerView.swift     # MODIFIED — mount InSessionPRBanner; seed PR table at session start
```

> **DTO name collision:** `fitbod/ExerciseLibrary/ExerciseDTO.swift` already exists (Phase 1 seed DTO). The export DTO needs a different name — recommend `ExportExerciseDTO` or place exports under `Export/DTOs/Exercise.swift` and refer to it as `Export.ExerciseDTO` via namespace.

### Pattern 1: Intent-split chart (two series, shared axes)

**What:** Render strength sessions and hypertrophy sessions as **distinct line series on the same axes**, color-and-stroke differentiated, with a per-series Toggle.
**When to use:** PROG-01 (`ExerciseProgressView`).
**Example (CITED pattern, paraphrased):**

```swift
// Source pattern: Apple Swift Charts samples + WWDC 2024 "Swift Charts: Vectorized and function plots"
// [CITED: developer.apple.com/documentation/Charts/PointMark, developer.apple.com/documentation/Charts/LineMark]
import Charts
import SwiftUI

struct ExerciseProgressChart: View {
    let series: [E1RMSeriesPoint]            // (date: Date, e1RM: Double, intent: Intent, kind: SeriesKind)
    @State private var showTopSet = true
    @State private var showAllAvg = true

    var body: some View {
        Chart(filteredSeries) { p in
            // Color encodes top-set vs all-avg; stroke style encodes intent.
            LineMark(
                x: .value("Date", p.date),
                y: .value("e1RM (kg)", p.e1RM)
            )
            .foregroundStyle(by: .value("Series", p.kind.label))           // Top set / All-set avg
            .lineStyle(StrokeStyle(
                lineWidth: 2,
                dash: p.intent == .hypertrophy ? [4, 3] : []                // dashed for hypertrophy
            ))
            .symbol(by: .value("Series", p.kind.label))

            PointMark(
                x: .value("Date", p.date),
                y: .value("e1RM (kg)", p.e1RM)
            )
            .foregroundStyle(by: .value("Series", p.kind.label))
            .symbolSize(p.kind == .topSet ? 60 : 40)
        }
        .chartForegroundStyleScale([
            "Top set":      Color(hex: 0x0E7C86),
            "All-set avg":  Color(hex: 0x3FBFC9),
        ])
        .chartXScale(domain: .automatic(includesZero: false))
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(minHeight: 240)
    }

    private var filteredSeries: [E1RMSeriesPoint] {
        series.filter {
            (showTopSet && $0.kind == .topSet) || (showAllAvg && $0.kind == .allSetAvg)
        }
    }
}
```

**Key notes:**
- `.foregroundStyle(by: .value("Series", …))` is the **only** way to drive a legend automatically; explicit per-series `LineMark` blocks lose the auto-legend.
- `.lineStyle(StrokeStyle(dash: …))` controls dash on the same color — pairs cleanly with `.foregroundStyle(by:)`.
- `Chart(filteredSeries)` re-builds the chart when filter state changes — at <1000 points this is cheaper than animation transitions.

### Pattern 2: Weekly tonnage with optional muscle stacking

```swift
// [CITED: developer.apple.com/documentation/Charts/BarMark]
Chart(weeklyAggregates) { week in
    if filterState.selectedMuscles.isEmpty {
        BarMark(
            x: .value("Week", week.weekStart, unit: .weekOfYear),
            y: .value("Tonnage (kg)", week.totalTonnage)
        )
        .foregroundStyle(Color(hex: 0x0E7C86))
    } else {
        // Stacked per-muscle within the bar
        ForEach(week.muscleBreakdown) { slice in
            BarMark(
                x: .value("Week", week.weekStart, unit: .weekOfYear),
                y: .value("Tonnage (kg)", slice.tonnage)
            )
            .foregroundStyle(by: .value("Muscle", slice.muscle.displayName))
        }
    }
    RuleMark(y: .value("Previous best", previousBestWeeklyTonnage))
        .foregroundStyle(.secondary)
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
        .annotation(position: .topTrailing, alignment: .trailing) {
            Text("Previous best")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
}
.chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) }
```

**Key notes:**
- Stacked bars happen automatically when multiple `BarMark`s share the same X value — no `.position(.stacked)` call needed (that's the iOS 17 default for BarMark on same X).
- `RuleMark` for "previous best" doesn't double-render across stacked bars — it's a chart-wide overlay.

### Pattern 3: Live PR banner overlay

```swift
// Mount on top of the SessionLoggerView LazyVStack. Layout: ZStack alignment .top,
// with the banner pinned via .safeAreaInset(edge: .top) so it doesn't shift set rows.
// [CITED: developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)]

struct SessionLoggerView: View {
    @State private var prState = InSessionPRState()
    // ... existing state

    var body: some View {
        Form {
            // existing exercise list
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let banner = prState.currentBanner {
                InSessionPRBanner(banner: banner)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: prState.currentBanner)
        .onChange(of: prState.currentBanner) { _, newValue in
            guard newValue != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run { prState.dismissIfStillCurrent(newValue) }
            }
        }
    }
}
```

**Key notes:**
- `.safeAreaInset(edge: .top)` keeps the banner outside the scroll content — so set rows never reflow when it appears/disappears. **This is the critical pattern.** Putting the banner inside the LazyVStack causes a layout shift on every save.
- `@Environment(\.accessibilityReduceMotion)` gates the transition (D-35).

### Pattern 4: CSV `Transferable`

```swift
// [CITED: developer.apple.com/documentation/CoreTransferable/Transferable]
// [CITED: developer.apple.com/documentation/CoreTransferable/FileRepresentation]

struct CSVFile: Transferable {
    let data: Data                 // Pre-rendered (off-main); see ExportService
    let filename: String           // e.g. "fitbod-export-2026-05-22.csv"

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            csv.data
        }
        .suggestedFileName { $0.filename }
    }
}

// In SettingsView:
if let csv = vm.csvFile {
    ShareLink(item: csv, preview: SharePreview(csv.filename))
}
```

**Key notes:**
- Use `DataRepresentation` (not `FileRepresentation`) when the file is built in-memory and not written to disk — avoids a wasted round-trip to the documents directory.
- `.suggestedFileName { $0.filename }` is the correct iOS 16+ API to inject the filename into the share sheet (Files app uses it).
- Render the CSV **off-main** before constructing the `CSVFile`. `ShareLink` itself is synchronous against the value, so the value must hold ready-rendered `Data`.

### Pattern 5: Backup `.fitbodbackup` (ZIP container via Apple `Compression` framework)

> **Container choice locked per D-30:** ZIP container via Apple `Compression` framework + a hand-written ZIP central-directory writer. Reverts the earlier AppleArchive recommendation. The AppleArchive code block below is retained for reference only — `BackupArchiver` in plan 06-10 uses `Compression` (`COMPRESSION_ZLIB` / DEFLATE or STORE method) plus a minimal PKWARE APPNOTE ZIP local-file-header / central-directory-record / end-of-central-directory writer (~150 LOC). The reader is symmetrical. CryptoKit SHA-256 still verifies `manifest.checksum` over `store.json` bytes. UTI conforms to `public.zip-archive` (not `public.data`).

#### Reference (deprecated — AppleArchive shape, kept for context):


```swift
// [CITED: developer.apple.com/documentation/applearchive/archivebytestream]
// [CITED: developer.apple.com/documentation/applearchive/archivestream]
import AppleArchive
import System

actor BackupWriter {
    func write(to url: URL,
               manifest: BackupManifest,
               storeJSON: Data,
               images: [URL]) throws {
        let writeStream = try ArchiveByteStream.fileStream(
            path: FilePath(url.path),
            mode: .writeOnly,
            options: [.create, .truncate],
            permissions: FilePermissions(rawValue: 0o644)
        )
        defer { try? writeStream.close() }

        let compressStream = try ArchiveByteStream.compressionStream(
            using: .lzfse, writingTo: writeStream
        )
        defer { try? compressStream.close() }

        let encodeStream = try ArchiveStream.encodeStream(writingTo: compressStream)
        defer { try? encodeStream.close() }

        // Required header field set per AppleArchive spec
        let header = try ArchiveHeader(keySet: "TYP,PAT,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")
        // ... write manifest.json, store.json, images/* via encodeStream.writeHeader(...) + writeBytes(...)
    }
}
```

**Key notes (REVISED — ZIP-locked per D-30):**
- Container is ZIP, not `.aar`. Plan 06-10 writes a minimal PKWARE ZIP using `Compression` (DEFLATE) or STORE method directly — the AppleArchive code above is retained as reference only.
- ZIP layout: one local-file-header + DEFLATE/STORE payload per entry (`manifest.json`, `store.json`, `images/<uuid>.jpg`), then a central-directory-record per entry, then a single end-of-central-directory record. CRC-32 computed over each uncompressed payload (zlib's `crc32_z` or hand-rolled table — both fine).
- UTI declaration in `fitbod/Info.plist`: `UTTypeConformsTo` includes `public.zip-archive` (NOT `public.data`).
- Trade-off accepted: ~150 LOC vs AppleArchive's ~50 LOC. Cross-platform readability of the backup is the load-bearing user decision driving the choice.

### Pattern 6: Restore + `.fileImporter`

```swift
// [CITED: developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:)]
.fileImporter(
    isPresented: $showingImporter,
    allowedContentTypes: [.fitbodBackup],
    allowsMultipleSelection: false
) { result in
    guard case let .success(urls) = result, let url = urls.first else { return }
    Task {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        try await restoreCoordinator.restore(from: url)
    }
}
```

**Key notes:**
- `startAccessingSecurityScopedResource()` is **mandatory** for files outside the app sandbox (e.g. Files app picks). Skipping it produces a silent permission failure.
- The restore coordinator owns the destructive-confirm alert, side-file backup, ModelContainer reset, decode-and-insert, and image directory restoration in one transaction.

### Anti-Patterns to Avoid

- **Wrapping `@Query` in a view-model.** FOUND-06 + project rule. `ExerciseProgressView` reads `@Query<SetEntry>` directly and transforms via pure functions inline (or via `@Observable` filter state).
- **Putting the PR banner inside the scrolling content.** Causes a layout shift on every save. Use `.safeAreaInset(edge: .top)` (Pattern 3).
- **Eagerly rendering CSV on every keystroke / settings open.** Render only when the user taps "Export". CSV at ~5-10K sets ≈ 1-3 MB string build — fast but not free, and absolutely not main-thread.
- **Using `ISO8601DateFormatter` instead of `Date.ISO8601FormatStyle`.** The class-based formatter is the legacy API; the format-style is the 2026 canonical surface and is `Sendable` + cheaper to allocate.
- **Computing PR table on every `SetEntry` save.** Build the PR table **once at session start** (D-14) and mutate it in-memory as new working sets are saved. Re-querying SwiftData per save is wasteful at the scale of a session.
- **Decoding backup directly into `@Model` types.** Always decode into `Codable` DTOs first, then translate DTOs → `@Model` rows in a single `try ctx.save()`. Decoding straight into `@Model` couples the export shape to live schema and breaks D-28's schema-stability guarantee.
- **Bundling 24-hour-format dates without explicit timezone.** Always emit ISO-8601 in UTC with the trailing `Z`. Specifics §"ISO-8601 in UTC for ALL export timestamps."
- **Forgetting `startAccessingSecurityScopedResource` on restore.** Silent fail.
- **Hand-rolling a UTType for `.fitbodbackup` at runtime.** Must be declared in Info.plist's `UTExportedTypeDeclarations`. Runtime registration via `UTType(filenameExtension:)` only works for `UTType(importedAs:)` which still requires Info.plist anchoring for export.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| ISO-8601 timestamp formatting | `String(format:)` with `%d-%02d-...` | `Date.ISO8601FormatStyle().timeZone(.gmt)` | Calendar boundaries, DST, leap seconds — formatter handles all of them. `[CITED: developer.apple.com/documentation/foundation/iso8601formatstyle]` |
| RFC-4180 CSV quoting | Manual `string.contains(",")` checks | A 20-line `RFC4180Encoder` helper, but **don't import** a third-party CSV lib | Quoting rules are tiny: quote any field containing `,` `"` `\r` `\n`; escape `"` as `""`. A static func is correct; an SPM dep is overkill. |
| ZIP / archive writing | Raw `zlib`/`Compression` calls | `AppleArchive` framework | AppleArchive handles header/footer/checksum/extents that raw Compression doesn't. |
| SHA-256 | OpenSSL bridging | `CryptoKit.SHA256.hash(data:)` | One line, no dependency. |
| Charts | DGCharts / SwiftUICharts / Charts (old) | `import Charts` (Apple Swift Charts) | Project rule — PROJECT.md "What NOT to Use" explicitly forbids DGCharts. |
| Time-zone math for "week start" | Manual `Calendar.dateComponents([.year, .weekOfYear], …)` rebuild | `Calendar.current.component(.weekOfYear, from: date)` paired with `UserSettings.weekStartsMonday` (already exists) | Existing `weekStartsMonday: Bool` field — read it; don't reimplement. |
| 1RM estimation | Re-derive formulas every call | Pure-function `OneRepMax.estimate(weight:reps:) -> Double?` with a `nil` return for `reps > 10` | One canonical kernel; tested once with `@Test(arguments:)`. |
| Backup checksum | Compare every field on restore | SHA-256 over `store.json` bytes in `manifest.json` | O(n) verify; one mismatched byte fails the whole restore (correct UX — backups are atomic). |

**Key insight:** Phase 6 is **almost entirely "wire native API correctly"** — the temptation to build helper layers should be resisted. Every helper either (a) maps to a known Apple API, or (b) is a pure-value-type math kernel that fits in <100 LOC.

## Runtime State Inventory

Not applicable — Phase 6 is **not a rename/refactor/migration phase**. No persistent fields change; no live service config; no OS-registered state; no secrets; no installed-artifact migration. The phase only adds:

- New SwiftUI views (Progress tab + InSessionPRBanner)
- New value types (math kernels + DTOs + Transferable wrappers)
- One additive `#Index` declaration on `SetEntry`
- A new `UTType` declared in `Info.plist`

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | None — no persistent field renames or new persistent fields | None |
| Live service config | None | None |
| OS-registered state | New `UTType` (`com.fitbod.fitbodbackup`) in Info.plist — registered by iOS on app install | One-time Info.plist edit (planner: dedicated task) |
| Secrets/env vars | None | None |
| Build artifacts | None | None |

> The only "OS-registered state" is the UTI declaration. Once declared in Info.plist, iOS handles registration on install. No manual `lsregister` step needed (iOS does this — that's a macOS-only tool).

## Common Pitfalls

### Pitfall 1: CONTEXT.md field names don't match SchemaV2

**What goes wrong:** CONTEXT.md (auto-generated, 2026-05-22) refers to `SetEntry.actualWeight`, `actualReps`, `actualRPE`, `performedAt`, and `setKind: SetKind`. The real schema has `weight: Double`, `reps: Int`, `rpe: Double?`, `completedAt: Date`, and `setTypeRaw: String` (computed `setType: SetType`). It also references `wasManualOverride: Bool` and `Exercise.smallestIncrement` as Phase-3 additions that are **not yet shipped** (Phase 3 is "Not started").
**Why it happens:** CONTEXT was auto-generated against earlier doc drafts; Phase 1 ship-state and Phase 2/3 doc drift weren't reconciled.
**How to avoid:** Planner MUST use the **real schema names from `fitbod/Models/SetEntry.swift`** and treat `wasManualOverride` + `smallestIncrement` as **not-yet-existing fields** that Phase 6 cannot depend on. D-17 (`wasManualOverride` doesn't suppress PR detection) becomes a no-op in v1 because the field doesn't exist yet. Similarly, "plate-rounded weight in charts" via `smallestIncrement` is N/A — charts just plot `setEntry.weight`.
**Warning signs:** First plan-time grep should be `rg "actualWeight|actualReps|actualRPE|performedAt|wasManualOverride|smallestIncrement" fitbod/Models/` — expect zero hits.

### Pitfall 2: `@Query` re-fires on every `SetEntry` insert anywhere

**What goes wrong:** A naive `@Query<SetEntry>` in `ExerciseProgressView` recomputes the entire series whenever **any** SetEntry is inserted anywhere in the app (including during the active workout in `SessionLoggerView`).
**Why it happens:** SwiftData reactivity tracks the table, not the predicate; predicate is applied client-side after re-fetch.
**How to avoid:** (a) Tighten the predicate to `(exercise.id == targetID)` so the post-fetch filter is cheap; (b) the `#Index` on `(exercise, completedAt)` (recommended addition) makes the indexed range scan fast even when the table grows; (c) when the user is viewing a chart **during** an active session, the live PR banner is the right surface — the chart will refresh on session save, which is the desired behavior. Don't over-engineer with manual debouncing.
**Warning signs:** Profile shows `ExerciseProgressView.body` re-running on every set save in Sessions tab.

### Pitfall 3: SwiftData `Predicate<SetEntry>` related-entity-ID compare footgun

**What goes wrong:** `#Predicate<SetEntry> { $0.sessionExercise?.exercise?.id == exerciseID }` silently returns the wrong rows or crashes at runtime because SwiftData's predicate compiler can't always traverse optional chains through related entities reliably.
**Why it happens:** Documented limitation of SwiftData `Predicate` macro pre-iOS 18; even on iOS 18 the chain `set.sessionExercise.exercise.id` is brittle.
**How to avoid:** Apply the local-let UUID-capture workaround already established in Phase 2 (`PreviousMatchingIntent`, `ExerciseHistoryIntentSplitTests` — STATE plan 05-01 explicitly notes "RESEARCH §6 Pitfall 1 local-let UUID + intent captures applied"). Bind the UUID to a `let` BEFORE the predicate body so it's a value, not a captured `KeyPath`. Where the predicate must still traverse, fall back to fetching the parent set and filtering in memory (acceptable at v1 scale of ~hundreds of sessions per exercise).

### Pitfall 4: e1RM at `reps == 1`

**What goes wrong:** Brzycki at `reps == 1`: `weight * 36 / (37 - 1) = weight * 1.0` → correct. Epley at `reps == 1`: `weight * (1 + 1/30) = weight * 1.0333` → **slightly inflates a true 1RM**.
**Why it happens:** Epley is designed for `reps >= 2`; at `reps == 1` it should degenerate to identity but doesn't.
**How to avoid:** Special-case `reps == 1` in `OneRepMax.estimate` — return `weight` directly. **Reps >= 2 uses formula branching per D-04** (Brzycki for ≤6, Epley for 7–10, nil for >10). Reps == 0 returns nil (degenerate).

### Pitfall 5: e1RM with bodyweight-signed-added weight

**What goes wrong:** Phase 2 supports signed bodyweight-added weight (`SetEntry.weight` can be negative for assistance). Plugging negative weight into Brzycki/Epley produces a meaningless "negative e1RM" that breaks chart axes.
**Why it happens:** Schema doesn't track bodyweight separately from added weight; the `signed weight` convention only makes physical sense if you also know bodyweight.
**How to avoid:** **Suppress e1RM** when `weight < 0` (return `nil`). Bodyweight-with-assist sets contribute to weekly tonnage as `abs(weight) * reps` or 0 (planner decision — recommend 0 for tonnage too, since the lifter's bodyweight isn't in the data model). Document explicitly.

### Pitfall 6: PR table seed-set lookup is expensive at session start

**What goes wrong:** For a routine with 8 exercises, building the PR table at session start runs 8 separate SwiftData fetches. On a cold launch with thousands of historical sets, that's tens of ms × 8 = perceptible delay.
**Why it happens:** Naive per-exercise loop.
**How to avoid:** One `FetchDescriptor<SetEntry>` keyed on `setEntry.sessionExercise.exercise.id IN [exerciseIDs]`, sorted by `(exerciseID, intent, weight DESC)`, fetched once, then partitioned in memory. The `#Index([\SetEntry.completedAt])` (proposed addition) makes the descending sort O(n log n) rather than table-scan.

### Pitfall 7: Swift Charts memory at very long time series

**What goes wrong:** Plotting an exercise with 10,000+ historical sets in Swift Charts hitches the UI thread on first render.
**Why it happens:** Swift Charts is convenient but not infinitely scalable. Apple-forum reports place the comfort ceiling around 5K-10K points before LineMark + PointMark starts noticeably hitching. `[ASSUMED — community-reported, no Apple-published guarantee]`
**How to avoid:** v1 is a personal app; D-36 sets the budget at 1000 sets. At 1000 sets per exercise this is a non-issue. If the user later hits >5K sets per exercise, the planner can switch `PointMark` → `PointPlot` (iOS 18+) which is the vectorized replacement; LineMark already vectorizes internally.

### Pitfall 8: ISO-8601 timezone defaults

**What goes wrong:** `Date.ISO8601FormatStyle()` without explicit `.timeZone(.gmt)` emits the **device's local time zone** with offset (`2026-05-22T07:33:00-07:00`), not UTC (`2026-05-22T14:33:00Z`). This breaks "self-describing across devices" promise of D-26.
**Why it happens:** Default format style picks `Calendar.current` and `TimeZone.current`.
**How to avoid:** Always construct as `.iso8601(timeZone: .gmt)` (or `.iso8601(timeZone: TimeZone(identifier: "UTC")!)`). Lock with a unit test that asserts the trailing `Z`.

### Pitfall 9: UTI declaration scope

**What goes wrong:** Declaring `UTType.fitbodBackup` only in Swift code (`UTType(exportedAs: "com.fitbod.fitbodbackup")`) without an Info.plist `UTExportedTypeDeclarations` entry — iOS recognizes the type at runtime but the Files app doesn't know about it, so the user can't tap-to-open `.fitbodbackup` from outside the app.
**Why it happens:** UTI declarations have two surfaces: runtime (Swift code) AND build-time (Info.plist). Both required.
**How to avoid:** Add `UTExportedTypeDeclarations` to the app target's Info.plist with `UTTypeIdentifier=com.fitbod.fitbodbackup`, `UTTypeConformsTo=public.zip-archive` (or `public.data` if using AppleArchive), `UTTypeTagSpecification.public.filename-extension=["fitbodbackup"]`, and a human-readable description. Also declare `CFBundleDocumentTypes` so iOS shows Fitbod in the "Open in…" sheet for backup files.

### Pitfall 10: ModelContainer reset on restore

**What goes wrong:** The user taps "Restore" → app deletes the SQLite store → re-instantiates `ModelContainer` → but **the in-memory `@Query`s in already-mounted views** still hold references to deleted entities, causing crashes / "zombie" rows.
**Why it happens:** SwiftUI views holding `@Query` results don't automatically reset when the underlying container is replaced.
**How to avoid:** **Restart the app after restore.** Show a "Restore complete. Restart Fitbod to load your data." alert with a single OK that calls `exit(0)` (acceptable in a personal app; the App Store would reject this in a commercial app). Alternative: hold the `ModelContainer` in a `@Observable` `AppState` that all views read via `.environment`, replace it atomically, and let SwiftUI re-mount the entire view tree — but the `exit(0)` approach is simpler and matches the personal-app voice.

### Pitfall 11: Cascade-delete-prevent on Exercise

**What goes wrong:** `Exercise → SessionExercise` is **nullify** on delete (LIB-05 / Cascade rules in SessionExercise.swift). If a user deletes a custom exercise, all historical `SessionExercise.exercise` references become `nil`. Charts and exports must handle this.
**Why it happens:** Deliberate schema choice (preserve history).
**How to avoid:** Charts skip `SessionExercise` rows where `exercise == nil`; exports include the `routineSnapshotName` + last-known exercise name (via `SessionExercise.routineSnapshotName` — wait, that's on `Session`). For exports, capture the exercise name **at session-log time** is not currently a field — the planner should either (a) add a future `SessionExercise.exerciseSnapshotName: String?` (small additive — but Phase 6 charter is "no schema changes"), or (b) emit empty-string for the exercise name on nullified rows in v1 exports, with a comment in the JSON manifest.

### Pitfall 12: Schema-version-skew on restore

**What goes wrong:** Restoring a `schemaVersion: "v3"` backup onto a `SchemaV2` install — D-32 spec requires hard reject. But the string-compare must be exact, and "v2" vs "2.0.0" vs "SchemaV2" inconsistency could let a wrong-version backup slip through.
**Why it happens:** The schema version is a free-text string in the manifest.
**How to avoid:** Define a single canonical `schemaVersion` constant in the app (`"v2"` for SchemaV2 — match D-28 wording) and assert exact `==` match on restore. Lock with a unit test that constructs a `manifest.json` with `"v3"` and expects rejection.

### Pitfall 13: ShareLink+Transferable lazy rendering on main thread

**What goes wrong:** A `Transferable` `DataRepresentation` closure runs on the calling thread of the share-sheet system. If you wire `{ csv in renderCSV(setEntries) }` and `renderCSV` is slow, the share sheet hangs.
**Why it happens:** The `DataRepresentation` closure is **not** automatically off-main.
**How to avoid:** Always render the CSV/JSON **before** constructing the `Transferable`. The pattern: tap "Export CSV" → show progress sheet → `Task.detached` renders into `Data` → construct `CSVFile(data: rendered, filename: …)` → set `@State` → render `ShareLink(item: csvFile)` only when non-nil.

## Code Examples

### OneRepMax (verified math)

```swift
// [CITED: en.wikipedia.org/wiki/One-repetition_maximum#Brzycki | Brzycki 1993; Epley 1985]
// Project decision D-04 anchors these formulas.

public enum OneRepMax {
    /// e1RM estimate per CONTEXT D-04. Returns nil for reps > 10 or reps <= 0
    /// or negative weight (bodyweight-assist), so callers can filter cleanly.
    public static func estimate(weight: Double, reps: Int) -> Double? {
        guard reps > 0, weight > 0 else { return nil }
        switch reps {
        case 1:
            return weight                                // identity — actual 1RM
        case 2...6:
            return weight * 36.0 / (37.0 - Double(reps)) // Brzycki
        case 7...10:
            return weight * (1.0 + Double(reps) / 30.0)  // Epley
        default:
            return nil                                   // suppress >10 per D-04
        }
    }
}
```

**Swift Testing pattern:**

```swift
import Testing
@testable import fitbod

struct OneRepMaxTests {
    @Test("Returns nil for reps > 10")
    func suppressesHighRep() {
        #expect(OneRepMax.estimate(weight: 60, reps: 11) == nil)
        #expect(OneRepMax.estimate(weight: 60, reps: 20) == nil)
    }

    @Test("Returns weight for reps == 1 (identity)")
    func identityAtOneRep() {
        #expect(OneRepMax.estimate(weight: 100, reps: 1) == 100)
    }

    @Test("Brzycki for reps 2..6", arguments: [
        (100.0, 5, 112.5),      // 100 * 36 / 32 = 112.5
        (60.0,  3, 63.529...),  // ~
    ] as [(Double, Int, Double)])
    func brzyckiRange(weight: Double, reps: Int, expected: Double) {
        let actual = try #require(OneRepMax.estimate(weight: weight, reps: reps))
        #expect(abs(actual - expected) < 0.5)
    }

    @Test("Nil for non-positive inputs")
    func nilOnEdgeInputs() {
        #expect(OneRepMax.estimate(weight: 0,    reps: 5)  == nil)
        #expect(OneRepMax.estimate(weight: -10,  reps: 5)  == nil)
        #expect(OneRepMax.estimate(weight: 100,  reps: 0)  == nil)
    }
}
```

### Backup round-trip Swift Testing pattern (D-33 acceptance test)

```swift
// [CITED: developer.apple.com/documentation/swiftdata/modelconfiguration/isstoredinmemoryonly]
@MainActor @Suite(.serialized)
struct BackupRoundTripTests {
    @Test("Export → wipe → import yields entity-by-entity equality")
    func roundTrip() async throws {
        // 1. Seed a known fixture into an in-memory container.
        let configA = ModelConfiguration(isStoredInMemoryOnly: true)
        let containerA = try ModelContainer(
            for: Schema(SchemaV2.models),
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: [configA]
        )
        let fixture = try seedFixture(into: containerA.mainContext)

        // 2. Export — render manifest+store.json bytes (no actual file write needed)
        let writer = BackupWriter()
        let archive = try await writer.archive(from: containerA, includingImages: false)

        // 3. Wipe — instantiate a brand-new in-memory container.
        let configB = ModelConfiguration(isStoredInMemoryOnly: true)
        let containerB = try ModelContainer(
            for: Schema(SchemaV2.models),
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: [configB]
        )

        // 4. Import — decode and insert.
        let reader = BackupReader()
        try await reader.restore(archive: archive, into: containerB)

        // 5. Equality — fetch sorted by id, diff via DTO equality.
        let dtoA = try ExportDocument(reading: containerA.mainContext).normalizedForEquality()
        let dtoB = try ExportDocument(reading: containerB.mainContext).normalizedForEquality()
        #expect(dtoA == dtoB)
    }
}
```

**Notes:**
- `.serialized` is required because the test mutates ModelContainer state — established Phase 2 convention.
- DTO equality (rather than direct `@Model` equality) sidesteps SwiftData identity-by-`ObjectID` quirks.
- The fixture should include: ≥1 Block + BlockPhase, ≥3 Routines (including one in a folder, one with a SupersetGroup), ≥10 Sessions covering multiple weeks + intents + warmups + drop sets + cluster reps + tempo, ≥1 custom exercise with `imageData`.

### `#Index` addition (the one schema delta)

```swift
// fitbod/Models/SetEntry.swift — proposed additive change for Phase 6
@Model
public final class SetEntry {
    #Index<SetEntry>(
        [\.completedAt],                                 // per-exercise chart range scans
        [\.isComplete, \.isWarmup]                       // common filter for "visible working sets"
    )
    // ... existing fields unchanged
}
```

**Effect:** Phase 6 chart queries like "all working sets for exercise X sorted by date" become indexed range scans instead of table scans. **No SchemaV3 required** — `#Index` declarations don't change the persistence format; SwiftData rebuilds the index on first launch after the app update.

> If the planner decides this single index is enough to warrant a `SchemaV3` bump for cleanliness, that's a judgment call — but per SwiftData docs index declarations are **non-persistent metadata** (`[CITED: developer.apple.com/documentation/swiftdata/index]`) and can land additively under SchemaV2 without a migration stage. **Recommendation: land under SchemaV2.** This matches D-28 / D-32 / CONTEXT statement that "Phase 6 adds NO new persistent fields."

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `ISO8601DateFormatter` class | `Date.ISO8601FormatStyle` | iOS 15 (2021) | Sendable, lighter alloc, format-style integrates with `formatted(_:)`. |
| `PointMark` for dense series | `PointPlot` (vectorized) | iOS 18 (2024) | 10-100× perf for >1K points. Use only if Phase 6 charts hit the ceiling. |
| Wrapping `@Query` in `@StateObject ViewModel` | `@Query` direct in view | iOS 17 / SwiftData (2023) | Project rule. |
| `ObservableObject` + `@Published` | `@Observable` macro | iOS 17 (2023) | Finer-grained reactivity. Project rule. |
| `ZIPFoundation` (3rd-party SPM) | `AppleArchive` framework | iOS 14 (2020), but ergonomic in iOS 17+ | Native, no SPM dep. |
| `Codable` per-property `encode(to:)` | `@Codable` macro / Codable synthesis | iOS 16+ for synthesis; macro patterns evolving | For Phase 6, use Codable synthesis on explicit DTOs. |

**Deprecated/outdated for this phase:**
- `ISO8601DateFormatter` — still functional but `Date.ISO8601FormatStyle` is canonical.
- `@StateObject` + `ObservableObject` — project rule forbids in new code (CLAUDE.md "What NOT to Use").
- `JSONSerialization` (low-level) — use `JSONEncoder/Decoder`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Swift Charts comfort ceiling ~5K-10K points before perceptible hitches | Pitfall 7 | Low — D-36 budget (1000 sets) is well under, even if ceiling is half what's claimed. |
| A2 | AppleArchive (`.aar`) is acceptable as the `.fitbodbackup` container per CONTEXT D-30's "ZIP container" language | Pattern 5 | Medium — if the user's mental model is "must unzip with Finder," `.aar` doesn't satisfy. Recommend planner surface this in plan-check / UI-SPEC. The technical alternative (hand-rolled ZIP) is feasible but ~150 LOC + edge cases. |
| A3 | `#Index` declarations are non-persistent metadata and can land under SchemaV2 without a migration stage | "#Index addition" | Low — Apple docs cited; consistent with how indices have worked since iOS 18. If wrong, planner adds a no-op `MigrationStage.lightweight` from V2 to V2.1. |
| A4 | `UTNotificationFeedbackGenerator.notificationOccurred(.success)` is the canonical 2026 haptic for "PR achieved" | Pattern 3 | None — well-established API. |
| A5 | `exit(0)` after restore is acceptable in a personal-install app | Pitfall 10 | Low — App Store would reject; user's app isn't on App Store per PROJECT.md. Alternative is more complex SwiftUI tree-reset; planner can choose. |
| A6 | `wasManualOverride` and `Exercise.smallestIncrement` fields don't exist yet (Phase 3 is "Not started") | Pitfall 1 | High if wrong — would invalidate D-17. Verified via direct read of `fitbod/Models/SetEntry.swift` and `Exercise.swift` — fields are NOT present. |
| A7 | CONTEXT.md field names `actualWeight/actualReps/actualRPE/performedAt/setKind` are documentation drift, not pending schema additions | Pitfall 1 | High if wrong — would force a schema migration. Verified via direct read of `fitbod/Models/SetEntry.swift`. |
| A8 | Apple's recommended pattern for "banner above scroll content that doesn't shift rows" is `.safeAreaInset(edge: .top)` | Pattern 3 | Low — standard idiom, used widely. |
| A9 | Brzycki at `reps == 1` correctly returns identity (`weight * 36 / 36 = weight`); Epley at `reps == 1` does not (returns `weight * 1.033`) | Pitfall 4 | None — derivable from arithmetic. |
| A10 | Phase 4 (Block / BlockPhase) entities are already shipped (Phase 1 schema) per CONTEXT and STATE | "D-19 dependency caveat" | Low — verified by direct read of `Block.swift` and `BlockPhase.swift`. Phase 4 populates them; the schema exists. |
| A11 | RFC 4180 quoting rules (quote fields containing `,` `"` `\r` `\n`; escape `"` as `""`) | D-26 mapping | None — RFC text. |

## Open Questions (RESOLVED)

1. **AppleArchive vs hand-rolled ZIP for `.fitbodbackup`?**
   - What we know: AppleArchive is simpler, native, but produces `.aar` (not a ZIP that Finder can unzip).
   - What's unclear: Whether CONTEXT.md D-30's "ZIP container" language is a hard requirement or a loose label.
   - Recommendation: Planner picks **AppleArchive** unless the user explicitly says "I want Finder to unzip this." Surface in plan-check.
   - **RESOLVED:** ZIP container via Apple `Compression` framework + a hand-written ZIP central-directory writer. Reverts the prior AppleArchive recommendation to honor D-30 (locked user decision) — CONTEXT D-30 line 169 explicitly permits "Apple Compression framework with a tiny zip header writer." Cross-platform readability is a load-bearing user decision; the extra ~150 LOC (local-file-header + central-directory-record + end-of-central-directory record per PKWARE APPNOTE) is accepted cost. Plan 06-10 implements `BackupArchiver.write(...) -> Data` producing a STORE-method (uncompressed) or DEFLATE-method ZIP, with `BackupRestorer` reading the same via `Compression` + manual central-directory parser. CryptoKit SHA-256 still verifies `manifest.checksum`. UTI declaration `LSItemContentTypes` conforms to `public.zip-archive`.

2. **Exercise-name snapshot in exports when `SessionExercise.exercise` is nil (post-delete)?**
   - What we know: Cascade is nullify; deleted-exercise sessions show `exercise == nil` (Pitfall 11).
   - What's unclear: Whether v1 export should emit empty-string + a comment in JSON, OR whether Phase 6 should add `SessionExercise.exerciseSnapshotName: String?` (a 1-field additive — minimal cost).
   - Recommendation: Add the snapshot field. It's tiny, defaults to empty string, and makes exports self-describing. Planner: weigh against "Phase 6 adds no persistent fields" guideline; if breaking that guideline is too costly, fall back to empty-string-and-comment.
   - **RESOLVED:** deferred. v1 emits empty string when exercise relationship is nil. Documented in 06-07 / 06-09 / 06-10 deferred notes. Adding the persistent field is a Phase 6 follow-up (or Phase 7 candidate) since this phase ships zero schema additions.

3. **`MuscleVolumeProvider` location — `Math/` or `Phase5Shim/`?**
   - What we know: Protocol abstracts a Phase 5 dependency that doesn't exist yet.
   - What's unclear: Whether to commit the unweighted default in Phase 6 and leave the protocol for Phase 5 to swap, or write the protocol in Phase 5 and have Phase 6 inject a closure.
   - Recommendation: Protocol in Phase 6's `Math/` directory; Phase 5 conforms `StimulusWeightedMuscleVolumeProvider` later. The Phase 6 default (`UnweightedMuscleVolumeProvider`) ships now and is replaced via DI at the call site without changing `WeeklyTonnageView`.
   - **RESOLVED:** Phase 6 ships `UnweightedMuscleVolumeProvider` as the default; Phase 5 swaps `StimulusWeightedMuscleVolumeProvider` later via DI at the `WeeklyTonnageView(provider:)` init site (already designed in plan 06-03 + 06-06).

4. **PR table seed: at session start or at view appear?**
   - What we know: D-14 says session-start; D-12 says PR list is computed on-demand from history.
   - What's unclear: Whether the in-session PR detector and the `ExercisePRsView` PR list share a cache.
   - Recommendation: **Don't share.** In-session detector caches at session start (small set: just the routine's exercises). `ExercisePRsView` queries on demand (single-screen, no scale issue). Different lifecycles → simpler to keep separate.
   - **RESOLVED:** in-session detector caches at session start via `SessionFactory.seedPRTable(...)`; `ExercisePRsView` recomputes on appear via its own `@Query<SetEntry>` + `PRDetector.buildTable`. No shared cache (different lifecycles).

5. **Restore: restart-via-exit(0) or atomic tree reset?**
   - What we know: `exit(0)` is simple but App-Store-illegal; tree reset via `@Observable` `AppState` is correct but more complex.
   - What's unclear: User's tolerance for the cliff-edge restart.
   - Recommendation: `exit(0)` with explicit alert copy ("Fitbod will restart to load your backup."). Personal app; the alternative is overkill.
   - **RESOLVED:** `exit(0)`. Personal-team / no-App-Store project; simplicity wins. Alert copy "Fitbod will restart to load your data." is the user-visible explanation.

6. **CSV "unit" column — per-row or per-file?**
   - What we know: D-25 lists `unit` as a column; D-26 says "weights in user's canonical unit."
   - What's unclear: At v1 the unit doesn't change per row (single user, single canonical unit per `UserSettings`). A per-row column is wasted bytes but maximally self-describing.
   - Recommendation: **Keep per-row** (D-25 spec). It's tiny (1-2 chars × N rows) and makes the CSV self-describing for any future unit-changing scenario.
   - **RESOLVED:** per-row `unit` column kept per D-25 spec. Trivial size cost; CSV is self-describing for any future unit-changing scenario.

7. **Charts dependency on `Exercise.smallestIncrement` for plate-rounded display?**
   - What we know: CONTEXT.md "Existing Code Insights" claims Phase 3 adds `Exercise.smallestIncrement` (used in charts).
   - What's unclear: Field doesn't exist yet (Phase 3 not started).
   - Recommendation: Phase 6 charts plot **raw `setEntry.weight`** without plate-rounding. When Phase 3 ships and adds the field, a small follow-up can adjust display.
   - **RESOLVED:** deferred. Phase 6 plots raw weight. Follow-up after Phase 3 ships the `Exercise.smallestIncrement` field — a single-display-helper change at the chart Mark level.


## Environment Availability

This phase is **pure code/config changes**; no external tools beyond Xcode 16 + iOS 18 SDK are required.

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Xcode 16+ | All | Assumed ✓ | 16.x or 26.x | None |
| iOS 18 SDK | All | Assumed ✓ | 18.0 | None |
| Swift Charts | Chart views | ✓ (SDK) | iOS 17+ | None |
| AppleArchive | Backup | ✓ (SDK) | iOS 14+ | Fall back to raw ZIP via Compression if needed |
| CryptoKit | Backup checksum | ✓ (SDK) | iOS 13+ | None |
| Swift Testing | Tests | ✓ (Xcode 16) | 16.x | XCTest (legacy) |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

> `workflow.nyquist_validation = true` in `.planning/config.json`. Validation Architecture is required.

### Test Framework

| Property | Value |
|---|---|
| Framework | Swift Testing (Xcode 16+, `import Testing`) for unit; XCTest with `XCUIApplication` for any UI test |
| Config file | Project-level — no separate config; targets are `fitbodTests` (Swift Testing) and `fitbodUITests` (XCTest) |
| Quick run command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/<SuiteName>` |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Parse-clean check | `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` (Phase 2 convention — STATE plan 05-01) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| PROG-01 | Intent-split LineMark series renders strength + hypertrophy as distinct stroke styles | Unit (data shape) + manual UI verify | `xcodebuild test -only-testing:fitbodTests/IntentSplitSeriesShapeTests` | ❌ Wave 0 |
| PROG-02 | e1RM math: Brzycki ≤6, Epley 7–10, nil for >10, identity at reps==1, nil for non-positive inputs | Unit | `xcodebuild test -only-testing:fitbodTests/OneRepMaxTests` | ❌ Wave 0 |
| PROG-03 | Top-set definition (highest e1RM, weight tiebreaker, latest-set tiebreaker); all-set-average excludes nil e1RM | Unit | `xcodebuild test -only-testing:fitbodTests/TopSetAndAverageTests` | ❌ Wave 0 |
| PROG-04 | Weekly tonnage = sum(weight × reps) over working sets, week boundary ISO-8601 Monday-start | Unit | `xcodebuild test -only-testing:fitbodTests/WeeklyTonnageAggregatorTests` | ❌ Wave 0 |
| PROG-05 | PR table per (exercise, intent): weightPR / repPR / volumePR / e1RMPR; rep-range bucketed; ranked top 3 | Unit | `xcodebuild test -only-testing:fitbodTests/PRDetectorTests` | ❌ Wave 0 |
| PROG-07 | Session comparison: matches prior session with same `sourceRoutineID` + intent, within 14 days, fetchLimit 1 | Unit (with in-memory ModelContainer) | `xcodebuild test -only-testing:fitbodTests/SessionComparatorTests` | ❌ Wave 0 |
| PROG-08 | Live PR detection: PRDetector.check(set:) returns the set of PRKinds the just-saved set achieved | Unit | `xcodebuild test -only-testing:fitbodTests/LivePRBannerTests` | ❌ Wave 0 |
| EXP-01 | CSV roundtrip: known fixture → CSV → re-parse → equal rows; RFC-4180 quoting + UTF-8 BOM + ISO-8601 UTC | Unit | `xcodebuild test -only-testing:fitbodTests/CSVExportTests` | ❌ Wave 0 |
| EXP-02 | JSON envelope shape: `formatVersion`/`schemaVersion`/`exportedAt`/`exercises[]`/…; encodes pretty + sortedKeys + ISO-8601 UTC | Unit | `xcodebuild test -only-testing:fitbodTests/JSONExportTests` | ❌ Wave 0 |
| EXP-03 | Backup writer composes manifest + store.json + images into a single archive; SHA-256 of store.json matches manifest.checksum | Unit | `xcodebuild test -only-testing:fitbodTests/BackupWriterTests` | ❌ Wave 0 |
| EXP-04 | Backup round-trip: seed → export → wipe → import → entity-by-entity equality (D-33 acceptance) | Unit (with in-memory ModelContainer) | `xcodebuild test -only-testing:fitbodTests/BackupRoundTripTests` | ❌ Wave 0 |
| EXP-04 | Schema-version-skew rejection: a manifest with `schemaVersion: "v3"` is rejected with a typed error | Unit | `xcodebuild test -only-testing:fitbodTests/BackupVersionSkewTests` | ❌ Wave 0 |
| (UI smoke) | Progress tab mounts, ExerciseProgressView renders for an exercise with logged data, Settings → Data section is present | UI (XCUIApplication) | `xcodebuild test -only-testing:fitbodUITests/ProgressTabSmokeTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing:fitbodTests/<modified-suite>` — runs the directly-impacted suite in <30s.
- **Per wave merge:** Full `fitbodTests` suite via `xcodebuild test -scheme fitbod`. UI tests deferred to phase gate.
- **Phase gate:** Full `fitbod` scheme (unit + UI) green before `/gsd:verify-work`. Backup round-trip is the **must-pass** acceptance test per ROADMAP success criterion #5.

### Wave 0 Gaps

- [ ] `fitbodTests/OneRepMaxTests.swift` — covers PROG-02 (math kernel)
- [ ] `fitbodTests/TopSetAndAverageTests.swift` — covers PROG-03
- [ ] `fitbodTests/PRDetectorTests.swift` — covers PROG-05 / PROG-08 (math)
- [ ] `fitbodTests/LivePRBannerTests.swift` — covers PROG-08 (banner state machine)
- [ ] `fitbodTests/WeeklyTonnageAggregatorTests.swift` — covers PROG-04
- [ ] `fitbodTests/SessionComparatorTests.swift` — covers PROG-07 (with in-memory ModelContainer per Phase 2 pattern)
- [ ] `fitbodTests/IntentSplitSeriesShapeTests.swift` — covers PROG-01 (data shape only; visual verification is manual)
- [ ] `fitbodTests/CSVExportTests.swift` — covers EXP-01
- [ ] `fitbodTests/JSONExportTests.swift` — covers EXP-02
- [ ] `fitbodTests/BackupWriterTests.swift` — covers EXP-03 (manifest + checksum)
- [ ] `fitbodTests/BackupRoundTripTests.swift` — covers EXP-04 (D-33 acceptance; in-memory ModelContainer)
- [ ] `fitbodTests/BackupVersionSkewTests.swift` — covers EXP-04 negative case
- [ ] `fitbodTests/ProgressViewCopyTests.swift` — UI-SPEC verbatim copy anchors (mirroring Phase 2 `*CopyTests` pattern)
- [ ] `fitbodUITests/ProgressTabSmokeTests.swift` — UI smoke: tab mounts; ExerciseProgressView pushes; Settings Data section visible
- [ ] `fitbodTests/TestSupport/ProgressFixtureFactory.swift` — shared seeded-history fixture (≥10 sessions across 4+ weeks across 3+ exercises, both intents)

No framework install needed — Swift Testing and XCTest are already wired (per existing test directory).

## Security Domain

> `security_enforcement` is not explicitly set in `.planning/config.json` — treating as enabled. This is a personal local-only app; ASVS categories that don't apply are documented as such.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | **no** | Single-user personal app; no auth surface |
| V3 Session Management | **no** | No remote session |
| V4 Access Control | **no** | No multi-user model |
| V5 Input Validation | **yes (light)** | Restore: validate `manifest.json` fields (schemaVersion regex, checksum hex, formatVersion integer). Reject unknown extra top-level keys with a warning, not a hard fail. |
| V6 Cryptography | **yes (light)** | SHA-256 via CryptoKit for backup integrity check. **Not** used for confidentiality — backup is unencrypted (no secrets in the data; backup is user-shared via AirDrop / Files at their discretion). |
| V7 Errors & Logging | **yes** | Backup/restore typed errors with user-facing messages; do not log raw file paths from outside the sandbox (could include user's iCloud Drive folder names). |
| V8 Data Protection | **yes (file-level)** | Backup files written to `.documentDirectory` use iOS default file protection. No additional encryption (would block AirDrop/Files round-trip if user changes devices). |
| V9 Communications | **no** | No network traffic in Phase 6 |
| V10 Malicious Code | **yes (light)** | Restore must reject backup files whose manifest checksum doesn't match the included store.json (corruption or tampering). Reject `..` path traversal in `images/` directory entries. |

### Known Threat Patterns for SwiftData + AppleArchive Backup/Restore

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Path traversal via `images/../../../something` in archive entry name | Tampering | Validate every archived entry's `PAT` field starts with `images/` and contains no `..` components. Reject archive on detection. |
| Malformed JSON in store.json crashes decode | DoS | `try? JSONDecoder().decode(ExportDocument.self, from: storeJSON)` — gracefully surface "Backup file is corrupted or from an incompatible version" alert. |
| Checksum mismatch between manifest and store.json | Tampering | SHA-256 compare; hard reject. |
| Schema version skew (future-format backup on older-format install) | Tampering / Compatibility | Exact `==` schemaVersion string match; reject with user-facing copy. |
| Decompression bomb (giant store.json in tiny archive) | DoS | Cap decoded `storeJSON` size at 100 MB (conservative — realistic v1 cap is <10 MB; gives plenty of headroom). Bail with typed error if exceeded. |
| Restore on top of an active session | Logical | Restore coordinator blocks if `Session.active(in:)` returns non-nil — user must finish or discard the live session first. |

## Schema reality vs CONTEXT (delta table)

For planner reference. Field names in CONTEXT.md vs actual SchemaV2:

| CONTEXT term | Actual SchemaV2 field | Owner | Phase 6 impact |
|---|---|---|---|
| `SetEntry.actualWeight` | `SetEntry.weight: Double` | SetEntry.swift | All charts/exports read `.weight` |
| `SetEntry.actualReps` | `SetEntry.reps: Int` | SetEntry.swift | Read `.reps` |
| `SetEntry.actualRPE` | `SetEntry.rpe: Double?` | SetEntry.swift | Read `.rpe` |
| `SetEntry.performedAt` | `SetEntry.completedAt: Date` | SetEntry.swift | Charts X-axis reads `.completedAt`; export emits as `completed_at` (CSV) / `completedAt` (JSON) |
| `SetEntry.setKind` | `SetEntry.setTypeRaw: String` + `setType: SetType` (computed) | SetEntry.swift | Read `.setType` for filters; export emits raw |
| `SetEntry.wasManualOverride` | **Does not exist** (Phase 3 future) | — | D-17 N/A in v1; no impact |
| `Exercise.smallestIncrement` | **Does not exist** (Phase 3 future) | — | Charts plot raw weight |
| `Session.intent` | **Does not exist** — intent lives on `SessionExercise.intentRaw` (per-exercise) | Session.swift / SessionExercise.swift | Session-comparison match must be per-exercise (compare matching `(routine, exercise, intent)` triples). CONTEXT D-22 simplification ("`session.intent`") needs rethinking — sessions don't have a single intent. |
| `Session.routine` | `Session.sourceRoutineID: UUID?` (soft reference) | Session.swift | Match by UUID, not by `==` on relationship |
| `setKind == .working` | `set.setType == .working` AND `!set.isWarmup` | SetEntry.swift | "Working" is computed as `set.setType == .working && !set.isWarmup` — keep both checks for defense |

> Update D-22's matching rule to: "for each `SessionExercise` in the current session, find the most recent prior `SessionExercise` where `sessionExercise.exercise == current.exercise`, `sessionExercise.intentRaw == current.intentRaw`, `sessionExercise.session.sourceRoutineID == current.session.sourceRoutineID`, and `current.session.startedAt - prior.session.startedAt < 14 days`." This is more correct given the schema.

## Project Constraints (from CLAUDE.md)

The following CLAUDE.md directives must be honored by every plan in Phase 6:

- **Stack:** SwiftUI + SwiftData; iOS 18 deployment target; Swift 6 strict concurrency.
- **No DGCharts.** Swift Charts only. Project's "What NOT to Use" table forbids `DGCharts` and `Charts` (the old SPM name).
- **No third-party SPM dependencies.** "Locked out — entire stack is Apple-native." This phase introduces zero packages.
- **No CloudKit / no iCloud sync.** Backup file is the only inter-device transfer mechanism in v1.
- **No HealthKit.** Out of scope.
- **No Apple Watch / no VBT.** Phone-only v1.
- **No App Store / TestFlight.** Personal install via Xcode.
- **`@Observable` for ephemeral state.** No `@Published` / `@StateObject` / `ObservableObject` in new code.
- **`@Query` directly in views.** No MVVM wrapper around `@Query` (FOUND-06).
- **Per-tab `NavigationStack`.** Never wrap `TabView` in a parent `NavigationStack`. Progress tab follows verbatim.
- **`@Attribute(.externalStorage)` for any blob data.** Already in place for `Exercise.imageData`.
- **`*Raw: String` enum persistence.** Any new enum that needs persistence follows the convention.
- **Swift Testing for new tests; XCTest for UI tests.**
- **`swift-format` (Xcode 16 bundled).** No SwiftLint enforcement.
- **No `cat << EOF` for file creation.** Use Write/Edit tools (orchestration constraint, not a code constraint).
- **GSD workflow enforcement.** Direct repo edits are gated behind GSD commands.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — Progress navigation entry points**
- D-01: Add a new "Progress" tab to `RootView`'s `TabView`. Tab order becomes Today / Routines / Library / Progress / Settings.
- D-02: Per-exercise chart also reachable from `ExerciseDetailView` and `ExerciseHistoryView` deep-linking to the same `ExerciseProgressView`.
- D-03: Each Progress tab has its own `NavigationPath`; tap-to-pop-to-root on re-tap.

**Area 2 — e1RM calculation and series**
- D-04: Brzycki for reps ≤6; Epley for 6 < reps ≤10; nil for reps >10.
- D-05: Top set = highest e1RM among working sets (NOT highest weight). Tiebreakers: highest weight, then latest.
- D-06: All-set-average = arithmetic mean of non-nil e1RMs; reps >10 excluded.
- D-07: Toggleable [Top set] + [All-set avg] chips, default ON. Strength = solid line; hypertrophy = dashed. Colors `#0E7C86` (top-set) and `#3FBFC9` (all-set-avg).
- D-08: X-axis = Date with `.automatic` domain; Y-axis = canonical-unit weight.
- D-09: Empty state when <2 sessions with non-nil e1RM: "Log 2 sessions to see your trend."

**Area 3 — PRs view (per-exercise)**
- D-10: Track weightPR, repPR, volumePR, e1RMPR per (exercise, intent).
- D-11: Rep-range buckets: 1–6, 7–10, >10.
- D-12: PR storage = on-demand computed; NO denormalized `PR` entity.
- D-13: 4-row layout, intent toggle, top 3 per bucket, tappable.

**Area 4 — Live PR detection (PROG-08)**
- D-14: `PRDetector.check(set:)` runs on working-set save; PR table built at session start.
- D-15: `InSessionPRBanner` capsule at top of `SessionLoggerView`; auto-dismiss after 5s or on next save; `.success` haptic; no exclamation points.
- D-16: Multiple PRs in one set → one banner with multiple chips. No banner queue.
- D-17: `wasManualOverride` doesn't suppress PR detection. **(N/A in v1 — field doesn't exist yet; planner: defer to Phase 3 follow-up.)**

**Area 5 — Weekly tonnage chart (PROG-04)**
- D-18: Tonnage = sum(weight × reps) over working sets; warmups + drops excluded; week = ISO-8601 Monday-start (configurable via `UserSettings.weekStartsMonday`).
- D-19: Three filter rows (Time range / Block phase / Muscle). Block-phase chips disabled until Phase 4 ships.
- D-20: Muscle stack source = stimulus-weighted (when Phase 5 lands) with unweighted fallback. Use `MuscleVolumeProvider` protocol for the swap.
- D-21: `BarMark` per week; `RuleMark` for "previous best week"; tap to drill into week-detail.

**Area 6 — Session comparison view (PROG-07)**
- D-22: Match = same `sourceRoutineID` + matching intent + within 14 days. **Re-spec per-exercise (see "Schema reality vs CONTEXT" §).**
- D-23: 2-column side-by-side per exercise with Δ in center. Sort by exercise order.
- D-24: Entry from completed-session summary AND Progress tab → "This week vs last week" card.

**Area 7 — CSV export (EXP-01)**
- D-25: One row per `SetEntry`. 23 columns (full list in CONTEXT).
- D-26: RFC 4180 + UTF-8 BOM + comma delimiter + RFC quoting + ISO-8601 UTC + booleans as `true`/`false` + empty for nil.
- D-27: `Transferable CSVFile` value type; filename `fitbod-export-{ISO-date}.csv`.

**Area 8 — JSON export (EXP-02)**
- D-28: Schema-versioned envelope (`formatVersion: 1`, `schemaVersion: "v2"`). `JSONEncoder` with `.prettyPrinted` + `.sortedKeys`. Codable DTOs, not `@Model` direct.
- D-29: `Transferable JSONFile`; filename `fitbod-export-{ISO-date}.json`.

**Area 9 — Backup / restore (EXP-03, EXP-04)**
- D-30: `.fitbodbackup` = archive of manifest.json + store.json + images/. Use Apple Compression/AppleArchive — no third-party. UTI `com.<bundle-id>.fitbodbackup` with `public.zip-archive`.
- D-31: Settings → Data → Create backup → ShareLink. No automatic backups in v1.
- D-32: Restore flow: fileImporter → verify checksum → verify schemaVersion exact match → destructive confirm → side-file backup → wipe + decode + restart.
- D-33: `BackupRoundTrip.test.swift` — must-pass acceptance test.

**Area 10 — Polish scope**
- D-34: Hand-written empty states on every new view.
- D-35: `.success` haptic for PR banner; `.selectionChanged` for chip toggles; transitions ≤200ms; reduce-motion aware.
- D-36: `ExerciseProgressView` < 300ms for 1000-set exercise (achieve via `#Index` + lazy series construction).
- D-37: Out of scope: onboarding overlays, animated chart entry, themable schemes.

### Claude's Discretion

- Exact chart styling (line weight, point mark size, axis label density) — UI-SPEC locks.
- Filter-chip row form factor (horizontal scroll vs wrapped) — UI-SPEC.
- ProgressHomeView layout (list / grid / hybrid) — UI-SPEC.
- Banner copy variations matching Phase 2 voice.
- Location of `CSVFile` / `JSONFile` (`Export/` vs alongside services) — planner choice.
- PR table compute timing (per-session vs Progress-tab-load) — planner profile-driven.
- ZIP-vs-AppleArchive implementation choice — planner picks simplest that satisfies UTI declaration.

### Deferred Ideas (OUT OF SCOPE)

- Automated/scheduled backups (v2).
- CloudKit sync (PROJECT.md exclusion).
- Per-muscle PR records (v2).
- Velocity-based progress (no VBT hardware in v1).
- Animated chart entry / scrubber overlay (defer until usage shows need).
- Body-silhouette muscle heatmap (Phase 5 owns).
- Weekly recap auto-surface (Phase 5 owns).
- Plateau-stall flag (Phase 5 owns; Phase 6 may read if available).
- Custom export presets (date-ranged, exercise-filtered) — v2.
- PR confetti — match project voice; no exclamation points.
- Backwards-compatible schema migration on restore — v1 requires exact schemaVersion match.

## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| PROG-01 | Per-exercise time-series chart with intent split — strength vs hypertrophy as distinct lines on the same chart | Pattern 1 (intent-split chart with `.foregroundStyle(by:)` + `.lineStyle(StrokeStyle(dash:))`); `ExerciseProgressView` reads `@Query<SetEntry>` directly |
| PROG-02 | e1RM trend per exercise (Brzycki ≤6, Epley 7–10, suppress >10) | `OneRepMax.estimate` kernel + `OneRepMaxTests` |
| PROG-03 | Top-set e1RM vs all-set-average e1RM as toggleable series | D-05/D-06 pure-function picker + `TopSetAndAverageTests` |
| PROG-04 | Weekly tonnage chart, sliceable by week / block phase / muscle group | Pattern 2 (BarMark + RuleMark + optional stack) + `WeeklyTonnageAggregator` + `MuscleVolumeProvider` protocol |
| PROG-05 | PRs view: weight/rep/volume/e1RM PRs, intent-matched, rep-range aware | `PRDetector` (computed-on-demand per D-12) + per-bucket aggregation |
| PROG-07 | Session comparison view: this-week vs same-routine last-week | `SessionComparator` + the schema-corrected match rule per "Schema reality vs CONTEXT" |
| PROG-08 | Live PR detection at set save (in-session banner) | Pattern 3 (`.safeAreaInset(edge: .top)` banner; haptic; reduce-motion); PR table seeded at session start |
| EXP-01 | CSV export (one row per set) | Pattern 4 (`Transferable CSVFile`); RFC-4180 encoder; UTF-8 BOM; `Date.ISO8601FormatStyle(timeZone: .gmt)` |
| EXP-02 | JSON export (schema-versioned envelope) | `ExportDocument` Codable DTO graph; `JSONEncoder([.prettyPrinted, .sortedKeys])` |
| EXP-03 | Full database backup file shareable via AirDrop / Files / iCloud Drive | Pattern 5 (AppleArchive `.aar` for `.fitbodbackup`); CryptoKit SHA-256 manifest; UTI declared in Info.plist |
| EXP-04 | Restore from backup with explicit confirmation; round-trip yields identical state | Pattern 6 (`.fileImporter` + security-scoped resource); BackupRoundTrip Swift Testing suite (D-33 acceptance) |

## Sources

### Primary (HIGH confidence)
- `[CITED: developer.apple.com/documentation/Charts]` — Swift Charts framework: LineMark, BarMark, PointMark, RuleMark, AreaMark, `.foregroundStyle(by:)`, `.lineStyle(StrokeStyle)`, `chartXScale`, `chartYScale`
- `[CITED: developer.apple.com/documentation/Charts/LineMark]` — LineMark with dash style
- `[CITED: developer.apple.com/documentation/Charts/BarMark]` — auto-stacking BarMark
- `[CITED: developer.apple.com/documentation/Charts/PointMark]` — point markers
- `[CITED: developer.apple.com/documentation/SwiftUI/View/safeAreaInset(edge:alignment:spacing:content:)]` — banner without scroll-content layout shift
- `[CITED: developer.apple.com/documentation/SwiftUI/View/fileImporter(isPresented:allowedContentTypes:onCompletion:)]` — restore file picker
- `[CITED: developer.apple.com/documentation/CoreTransferable/Transferable]` — `Transferable` protocol
- `[CITED: developer.apple.com/documentation/CoreTransferable/DataRepresentation]` — Data-backed Transferable
- `[CITED: developer.apple.com/documentation/CoreTransferable/FileRepresentation]` — File-URL-backed Transferable with `.suggestedFileName`
- `[CITED: developer.apple.com/documentation/SwiftUI/ShareLink]` — `ShareLink(item:)` semantics
- `[CITED: developer.apple.com/documentation/Foundation/ISO8601FormatStyle]` — `Date.ISO8601FormatStyle` with `.timeZone(.gmt)`
- `[CITED: developer.apple.com/documentation/Foundation/JSONEncoder]` — `.prettyPrinted`, `.sortedKeys`, `.iso8601` strategies
- `[CITED: developer.apple.com/documentation/UIKit/UINotificationFeedbackGenerator]` — `.success` haptic
- `[CITED: developer.apple.com/documentation/CryptoKit/SHA256]` — SHA-256 hash for manifest checksum
- `[CITED: developer.apple.com/documentation/AppleArchive]` — `.fitbodbackup` archive container
- `[CITED: developer.apple.com/documentation/AppleArchive/ArchiveByteStream]` — Archive write API
- `[CITED: developer.apple.com/documentation/UniformTypeIdentifiers]` — `UTType.fitbodBackup` declaration
- `[CITED: developer.apple.com/documentation/SwiftData/Index]` — non-persistent `#Index` metadata
- `[CITED: developer.apple.com/documentation/SwiftData/ModelConfiguration]` — `isStoredInMemoryOnly` for tests
- `[CITED: developer.apple.com/documentation/Testing]` — Swift Testing framework
- `fitbod/Models/*.swift` — direct read of SchemaV2 entities (the source of the "Schema reality vs CONTEXT" deltas)

### Secondary (MEDIUM confidence)
- e1RM formula identities (Brzycki 1993, Epley 1985): widely-cited strength training literature; arithmetic verified inline in Pattern A4.
- RFC 4180 (CSV common format): IETF informational; quoting rules verified inline.
- `[ASSUMED — community-reported]` Swift Charts comfort ceiling ~5K–10K points; Apple has not published a numeric guarantee.

### Tertiary (LOW confidence)
- None — Phase 6 stays entirely within well-documented Apple APIs and known math.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — every choice is an Apple-native API already in use elsewhere in the project, with `[CITED]` documentation anchors.
- Architecture: **HIGH** — vertical-slice carving + pure-kernel separation aligns with Phase 2/3 established patterns and FOUND-06/FOUND-07.
- Math kernel: **HIGH** — formulas derived algebraically; edge cases (reps==1, negative weight, reps>10) explicit.
- PR detection: **HIGH** — pure-function design + session-start cache pattern documented.
- Charts: **HIGH** for shape; **MEDIUM** on performance ceiling at extreme scale (well above v1 budget).
- CSV/JSON export: **HIGH** — RFC 4180 + JSON envelope schema fully spec'd; Transferable wiring is a single-screen pattern.
- Backup container choice: **MEDIUM** — AppleArchive vs raw ZIP is a judgment call; recommendation provided but planner should adjudicate per the CONTEXT D-30 "ZIP" language.
- Restore flow: **HIGH** — `.fileImporter` + security-scoped resource + ModelContainer reset is well-documented Apple pattern; `exit(0)` restart is the only debatable bit.
- Pitfalls: **HIGH** — Phase 2 STATE.md explicitly references the "RESEARCH §6 Pitfall 1 local-let UUID + intent captures" workaround, confirming the SwiftData Predicate footgun is real and the workaround is the project's established remedy.

**Research date:** 2026-05-22
**Valid until:** 2026-06-22 (Apple Charts/Transferable APIs change slowly; iOS 18 is the current target; revisit only if Apple ships iOS 19 with notable Charts changes)
