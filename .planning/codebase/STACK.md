# Technology Stack

**Analysis Date:** 2026-05-28

## Languages

**Primary:**
- Swift 6.0 — application code in `fitbod/` and `FitbodWidgets/` targets (`fitbod.xcodeproj/project.pbxproj:614`, `:659`)
- Swift 5.0 — test targets only: `fitbodTests`, `fitbodUITests`, and `FitbodWidgetsExtension` (`fitbod.xcodeproj/project.pbxproj:682`, `:706`, `:729`, `:785`, `:817`)

**Secondary:**
- None. No Objective-C, C, or other languages in source.

## Runtime

**Platform:**
- iOS (`iphoneos`, `iphonesimulator`) — `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `SDKROOT = auto` (`fitbod.xcodeproj/project.pbxproj:609`, `:607`)
- macOS not targeted (the `LD_RUNPATH_SEARCH_PATHS[sdk=macosx*]` entry is a default-template leftover)

**Deployment target:**
- **iOS 26.4** (`IPHONEOS_DEPLOYMENT_TARGET = 26.4` on every target — `fitbod.xcodeproj/project.pbxproj:600`, `:645`, `:672`, `:696`, `:719`, `:742`, `:770`, `:802`)
- **Discrepancy:** `CLAUDE.md` claims "iOS 18.0" as the target. The project is actually set to iOS 26.4 (the OS shipped with Xcode 26). Anything in `CLAUDE.md` framed as "use iOS 17 fallback / iOS 18 unlocks" is stale — every iOS 18+ API (`#Index`, `#Unique`, `@Previewable`, `PointPlot`) and every iOS 26 API is available.

**Device families:**
- iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"` — `:615`)
- Orientations: portrait + landscape on iPhone; all four on iPad (`:598`–`:599`)

**Toolchain:**
- Xcode 26.4.1 created every target (`CreatedOnToolsVersion = 26.4.1` — `:326`, `:329`, `:333`, `:337`)
- Project object version 77, archive version 1, `LastUpgradeCheck = 2650` (`:6`, `:323`)

## Frameworks

### Core (Apple system frameworks)

| Framework | Where used | Cited at |
|---|---|---|
| **SwiftUI** | UI throughout app + widget | `fitbod/fitbodApp.swift:27`; explicit `SwiftUI.framework` link in widget target (`project.pbxproj:161`, `:203`) |
| **SwiftData** | Persistence; `ModelContainer`, `Schema(SchemaV6.models)`, `FitbodSchemaMigrationPlan` | `fitbod/fitbodApp.swift:28`, `:35`, `:38–42` |
| **WidgetKit** | Widget Extension entry; `WidgetBundle` | `FitbodWidgets/FitbodWidgetsBundle.swift`; explicit framework link `project.pbxproj:162`, `:202` |
| **ActivityKit** | Rest-timer Live Activity (`Activity<RestTimerAttributes>.request`) | `fitbod/Sessions/RestTimer/RestTimerActivityController.swift:29` (`@preconcurrency import ActivityKit`), `:75`, `:97`; `FitbodWidgets/RestTimerLiveActivity.swift` |
| **Charts** (Swift Charts) | Progress + tonnage charts (`BarMark`, `LineMark`, `PointMark`, `RuleMark`) | `fitbod/Progress/ExerciseProgressView.swift:49`, `fitbod/Progress/WeeklyTonnageView.swift:38` |
| **UserNotifications** | Rest-timer fallback notifications (`UNTimeIntervalNotificationTrigger`) | `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift:73`, `:87`, `:109`, `:122`, `:132` |
| **CryptoKit** | Backup file SHA-256 manifest hashing | `fitbod/Backup/BackupArchiver.swift:39`, `:64`; `fitbod/Backup/BackupRestorer.swift:60`, `:130` |
| **PhotosUI** | Custom-exercise image picker (`PhotosPicker`) | `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift:80` |
| **CoreTransferable** | Backup / JSON / CSV export `Transferable` conformances | `fitbod/Backup/FitbodBackupFile.swift:29`, `fitbod/Export/JSONFile.swift:14`, `fitbod/Export/CSVFile.swift:24` |
| **UniformTypeIdentifiers** | `UTType.fitbodBackup` + `.fileImporter` content-type filters | `fitbod/Backup/UTType+FitbodBackup.swift` |
| **OSLog** | Structured logging via `Logger(subsystem:category:)` | `fitbod/App/RootView.swift:53`, `:70`; `fitbod/Export/ExportService.swift:33`, `:39`; `fitbod/Backup/BackupArchiver.swift:41`, `:47`; `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift:52`, `:78` |
| **UIKit** | Bridging (font registration callsites, image data) | imports present in app + test targets |
| **Observation** | `@Observable` macro plumbing | import present in app target |
| **Foundation** | Standard | ubiquitous |
| **AppIntents** | Declared in project but **not used in source** (see `INTEGRATIONS.md`) | `project.pbxproj:78`, `:137`, `:145`, `:153` — linked to app + both test targets; zero `import AppIntents` in `fitbod/` or `FitbodWidgets/` |

### Testing

| Framework | Target | Notes |
|---|---|---|
| **Swift Testing** (`Testing`) | `fitbodTests/` | New unit tests use `@Test` / `#expect` (`import Testing` present in test sources). 137 Swift files under `fitbodTests/`. |
| **XCTest** | `fitbodTests/` + `fitbodUITests/` | Used alongside Swift Testing in unit tests; UI tests (20 files in `fitbodUITests/`) exclusively use `XCUIApplication`. |

### Build / dev

- **swift-format** — bundled with Xcode 26 toolchain; no build phase invocation found in `project.pbxproj`. Run manually.
- **SwiftLint** — not configured (no `.swiftlint.yml`, no SPM plugin reference).
- **xcodebuild** — used in `scripts/` and via `RootView.swift:53` workflow per `CLAUDE.md`; standard Xcode build commands.

## Key Dependencies

**Third-party Swift packages:**
- **None.** No `Package.swift` at root, no `Package.resolved` anywhere in the workspace (`find ... -name "Package.resolved"` empty), and `packageProductDependencies = ();` for every target in `project.pbxproj` (`:244`, `:267`, `:290`, `:309`).
- The app is **100 % first-party + Apple system frameworks**.

## Configuration

**Compile-time settings (per app/widget target, both Debug + Release):**
- `SWIFT_VERSION = 6.0` (app + widget — `:614`, `:659`)
- `SWIFT_STRICT_CONCURRENCY = complete` (app — `:612`, `:657`); widget inherits Swift 5 + `SWIFT_APPROACHABLE_CONCURRENCY = YES` (`:782`, `:814`)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` (all targets)
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` (all targets)
- `ENABLE_PREVIEWS = YES` (`:585`, `:630`)
- `ENABLE_APP_SANDBOX = YES` (`:584`, `:629`) — sandbox is on
- `ENABLE_USER_SELECTED_FILES = readonly` (`:586`, `:631`) — user-picked files allowed read-only (used by Backup restore + image picker)
- `DEAD_CODE_STRIPPING = YES` (every target)
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES` (`:509`, `:513`)
- `CLANG_CXX_LANGUAGE_STANDARD = "gnu++20"`, `GCC_C_LANGUAGE_STANDARD = gnu17` (`:463`, `:495`)
- `GENERATE_INFOPLIST_FILE = NO` for the app (uses checked-in `fitbod/Info.plist`); `YES` for widget + tests (`:587`, `:632`, `:671`, `:695`, `:765`, `:797`)

**Bundle identifiers:**
- App: `bodybuilding.fitbod` (`:604`, `:649`)
- Widget Extension: `bodybuilding.fitbod.FitbodWidgets` (`:777`, `:809`)
- Tests: `bodybuilding.fitbodTests`, `bodybuilding.fitbodUITests` (`:674`, `:698`, `:721`, `:744`)

**Versions:**
- `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` everywhere
- Pre-v1 (per `STATE.md`/`v1.0-MILESTONE-AUDIT.md`)

**Info.plist highlights (`fitbod/Info.plist`):**
- `NSSupportsLiveActivities = true` (`:25`) — also pinned in pbxproj `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (`:589`, `:634`)
- `UIAppFonts` registers six bundled fonts (`:27–35`): `SpaceGrotesk-Bold/SemiBold`, `JetBrainsMono-Regular/Bold`, `BebasNeue-Regular`, `Geist-Regular`
- `CFBundleDocumentTypes` + `UTExportedTypeDeclarations` declare the exported UTI `bodybuilding.fitbod.fitbodbackup` (zip-archive conformant, `.fitbodbackup` extension) for the backup pipeline (`:64–97`)
- No `NSAppTransportSecurity` — the app makes no network calls

## Platform Requirements

**Development:**
- macOS with Xcode 26.4.1 or newer
- Personal Apple ID team for signing (`CODE_SIGN_STYLE = Automatic` — `:581`, `:626`)
- No `Package.resolved` to restore; first build is dependency-free

**Production / install:**
- iPhone or iPad running iOS 26.4+ (Apple Watch not targeted; widget targets phone + iPad)
- Personal install via Xcode (per `CLAUDE.md` — no TestFlight / App Store)

## Notable absences (verified by grep)

- **No HealthKit, CloudKit, Combine** — zero matches for `import HealthKit`, `import CloudKit`, `import Combine` in `fitbod/` or `FitbodWidgets/`
- **No networking** — zero `URLSession` / `URLRequest` / `http(s)://` references outside `fitbod/Resources/ExerciseSeed/SOURCE.md` (which only documents a manual curl refresh procedure)
- **No third-party SDKs of any kind** — no SPM, no CocoaPods (`Podfile` absent), no Carthage

---

**Confidence**

- **Direct-read (project.pbxproj, Info.plist, source imports):** deployment target, Swift versions, framework links, target structure, every entry citing a `project.pbxproj:LINE` or source `.swift:LINE`.
- **Direct-read (grep):** the absence of HealthKit/CloudKit/Combine/URLSession/SPM, and the fact that `AppIntents` is linked but no source imports it.
- **Inferred:** Xcode 26 maps to "iOS 26 family" — the deployment target string `26.4` is the literal pbxproj value; the implication that this is "Xcode 26 era" relies on the matching `CreatedOnToolsVersion = 26.4.1`.
- **Flagged inconsistency:** `CLAUDE.md` says iOS 18 target — project is set to 26.4. Treat the project as authoritative.

*Stack analysis: 2026-05-28*
