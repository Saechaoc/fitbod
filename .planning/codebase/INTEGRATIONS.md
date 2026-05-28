# External Integrations

**Analysis Date:** 2026-05-28

## Scope summary

Fitbod is **offline-first and entirely local**. There are no remote APIs, no analytics SDKs, no auth providers, no cloud sync, and no push servers. Every "integration" is either an Apple system framework, a one-time bundled dataset, or user-driven file I/O. Two declared-but-unused surfaces are flagged below.

## APIs & External Services

**None at runtime.** No `URLSession`, `URLRequest`, or HTTP literal usages exist in `fitbod/` or `FitbodWidgets/` (verified by grep — only mention is the manual `curl` refresh instructions in `fitbod/Resources/ExerciseSeed/SOURCE.md:25`).

## Bundled Data Sources

### free-exercise-db (`exercises.json`) — the exercise catalog

- **What:** Vendored snapshot of [`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db) used to seed the `Exercise` catalog on first launch.
- **Where:** `fitbod/Resources/ExerciseSeed/exercises.json` (~1.0 MB, 900 rows raw / 702 after the strength filter, per `fitbod/Resources/ExerciseSeed/SOURCE.md:10–11`)
- **Provenance pinned in:** `fitbod/Resources/ExerciseSeed/SOURCE.md` — upstream commit `acd61f751fe15d618862ee3084f27e839222a28f`, vendored 2026-05-10, plus 27 locally added Panatta machine entries.
- **Version stamp:** `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` (currently `2`).
- **License:** The Unlicense (public domain, no attribution).
- **Consumed by:** `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift` — reads `SEED_VERSION.txt` (line 86), reads `exercises.json` from `Bundle.main` (line 152), idempotency tracked via `UserDefaults["exercise_seed_version"]` (line 64). DTO at `fitbod/ExerciseLibrary/ExerciseDTO.swift`.
- **Refresh path:** Manual `curl` documented in `SOURCE.md:23–26`; no automated download.

### Bundled fonts

- **Where:** `fitbod/Resources/Fonts/` — `SpaceGrotesk-{Bold,SemiBold}.ttf`, `JetBrainsMono-{Regular,Bold}.ttf`, `BebasNeue-Regular.ttf`, `Geist-Regular.ttf` plus per-font OFL license texts under `Fonts/LICENSES/`.
- **Registered by:** `fitbod/Info.plist:27–35` (app) and `INFOPLIST_KEY_UIAppFonts = "SpaceGrotesk-Bold.ttf SpaceGrotesk-SemiBold.ttf JetBrainsMono-Regular.ttf JetBrainsMono-Bold.ttf"` for the widget target (`fitbod.xcodeproj/project.pbxproj:769`, `:801` — widget registers a smaller subset).
- **Consumed by:** BRU type tokens in `fitbod/Design/BRUFont.swift`.

## Data Storage

**Database:**
- SwiftData, local-only, on-disk store
- Container created in `fitbod/fitbodApp.swift:38–42` with `ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)` against `SchemaV6.models`
- Migration plan: `FitbodSchemaMigrationPlan` (V1 → V6 chain) — referenced at `fitbodApp.swift:40`
- No CloudKit syncing (no `CloudKit` import, no `cloudKitDatabase:` argument)

**File storage:**
- Local filesystem under the app sandbox
- Documents directory accessed for backup archiving (`fitbod/Backup/BackupArchiver.swift:108`) and restore (`fitbod/Backup/BackupRestorer.swift:199`) via `FileManager.default.url(for: .documentDirectory, ...)`.

**Caching:**
- None. SwiftData `@Query` results are the cache. No `URLCache`, no `NSCache`, no Realm/SQLite layer.

**Preferences:**
- `UserDefaults.standard` (no app-group suite — see "Notable absences"). Keys observed:
  - `"exercise_seed_version"` — exercise-catalog seed stamp (`fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift:64`)
  - `"plateInventorySeeded"` — plate-inventory first-run flag (`fitbod/Settings/PlateInventorySeeder.swift:31`, `:49`, `:60`, `:76`)
  - Other seeders (`MuscleVolumeTargetSeeder`, `StimulusWeightSeeder`) intentionally do **not** use `UserDefaults` flags (idempotent by content)

## Authentication & Identity

- **None.** Single-user, on-device. No login, no Sign in with Apple, no Keychain credential use (CryptoKit is only used for backup hashing, not auth).

## Live Activities & Notifications

### ActivityKit (Live Activity for rest timer)

- **Attributes:** `fitbod/Sessions/RestTimer/RestTimerAttributes.swift` (`ActivityAttributes` conformance at line 41) — shared between app and widget extension (excluded from widget target only by file-system synchronized rule at `project.pbxproj:97`).
- **Lifecycle owner:** `fitbod/Sessions/RestTimer/RestTimerActivityController.swift` — `@preconcurrency import ActivityKit` (line 29); guards on `ActivityAuthorizationInfo().areActivitiesEnabled` (line 75); requests Activity via `Activity<RestTimerAttributes>.request(...)` (line 97). Holds the single `Activity<RestTimerAttributes>?` reference (line 58).
- **Bridge layer:** `fitbod/Sessions/RestTimer/RestTimerLiveActivityBridge.swift` — `@preconcurrency import ActivityKit` is the only file beyond `RestTimerActivityController.swift` with this annotation.
- **Widget UI:**
  - `FitbodWidgets/RestTimerLiveActivity.swift` — `Widget` conformance (line 39), declares `ActivityConfiguration` with lock-screen + Dynamic Island presentations
  - `FitbodWidgets/RestTimerDynamicIslandCompactView.swift`
  - `FitbodWidgets/RestTimerDynamicIslandExpandedView.swift`
  - `FitbodWidgets/RestTimerLockScreenView.swift`
- **Entry point:** `FitbodWidgets/FitbodWidgetsBundle.swift:22–23` (`var body: some Widget { RestTimerLiveActivity() }`)
- **Entitlement:** `com.apple.developer.usernotifications.live-activities = true` — `fitbod/fitbod.entitlements:5–6`
- **Info.plist:** `NSSupportsLiveActivities = true` in both `fitbod/Info.plist:25–26` and `FitbodWidgets/Info.plist:24–25`

### UserNotifications (rest-timer fallback)

- **Where:** `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift`
- **What:** Single `UNTimeIntervalNotificationTrigger` per rest timer, stable identifier per session to dedupe (lines 73, 109, 122, 132)
- **Authorization:** `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])` (line 87) — alert + sound only, no badge, no provisional
- **Engine integration:** `fitbod/Sessions/RestTimer/RestTimerEngine.swift:74`, `:86`, `:207` references documented behavior
- **No push notifications** — no remote-notification entitlement, no APNs registration, no device-token handling

## CryptoKit usage (backup integrity)

- **Where:** `fitbod/Backup/BackupArchiver.swift:39`, `:64` (`SHA256.hash(data: storeJSON)`); `fitbod/Backup/BackupRestorer.swift:60`, `:130` (`SHA256.hash(data: storeEntry.data)`).
- **Purpose:** SHA-256 manifest checksums embedded in `BackupManifest`; restore compares manifest hash against unpacked store data, throws `.checksumMismatch` on divergence (`fitbod/Backup/BackupManifest.swift:23`).
- **No cryptographic auth, signing, or encryption** — hashes only.

## File I/O (user-driven, sandboxed)

**Imports / exports declared via `Transferable` / SwiftUI file pickers:**

| Surface | File | Role |
|---|---|---|
| JSON export | `fitbod/Export/JSONFile.swift:14` (`import CoreTransferable`) | `Transferable` JSON file produced by Export |
| CSV export | `fitbod/Export/CSVFile.swift:24` (`import CoreTransferable`) | `Transferable` CSV file |
| Backup file | `fitbod/Backup/FitbodBackupFile.swift:29` (`import CoreTransferable`) | `Transferable` `.fitbodbackup` (zip) |
| UTI declaration | `fitbod/Backup/UTType+FitbodBackup.swift` | Custom UTI used by `.fileImporter(allowedContentTypes: [.fitbodBackup])` (line 15 comment); matches the `bodybuilding.fitbod.fitbodbackup` declaration in `fitbod/Info.plist:64–97` |
| Image picker | `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift:80` | `PhotosPicker` for custom-exercise photos; uses `PhotosPickerItem.loadTransferable(type: Data.self)` (line 89) |

**Sandbox posture:**
- `ENABLE_APP_SANDBOX = YES` (`fitbod.xcodeproj/project.pbxproj:584`, `:629`)
- `ENABLE_USER_SELECTED_FILES = readonly` (`:586`, `:631`) — user-picked files are read-only; writes go to the app sandbox container
- Sandbox flag is also redeclared in `fitbod/fitbod.entitlements:7–8` and `FitbodWidgets/FitbodWidgets.entitlements:5–6`

## Webhooks & Callbacks

- **Incoming:** none. No URL scheme registered in `fitbod/Info.plist` (no `CFBundleURLTypes`), no `onOpenURL`, no Universal Links.
- **Outgoing:** none.

## CI/CD & Deployment

- **No CI configuration in repo:** no `.github/workflows/`, no `.gitlab-ci.yml`, no `fastlane/`, no `Fastfile`. (Confirmed by the root `ls -la` showing only `.git`, `.gitignore`, `.mcp.json`, `.planning/`, `.gitnexus/`, `.claude/`, `.repowise/` as dotfiles.)
- **Hosting / distribution:** Personal install via Xcode run-to-device (per `CLAUDE.md`). No App Store Connect / TestFlight integration.

## Monitoring & Observability

**Error tracking:**
- None (no Sentry, Crashlytics, Datadog, Bugsnag, Firebase). Verified by grep.

**Logs:**
- `OSLog` `Logger` instances scoped by subsystem `"com.fitbod.app"` and category labels:
  - `category: "seed"` — `fitbod/App/RootView.swift:70`, `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift:78`
  - `category: "export"` — `fitbod/Export/ExportService.swift:39`
  - `category: "backup"` — `fitbod/Backup/BackupArchiver.swift:47`
- View via Console.app filtered on subsystem `com.fitbod.app`.

**Analytics:**
- None.

## Environment Configuration

- **No environment variables read at runtime** — no `ProcessInfo.environment[...]` lookup found outside test scaffolding.
- **No `.env*` files in repo** (confirmed by root `ls -la`).
- **Signing:** `CODE_SIGN_STYLE = Automatic` for every target (`project.pbxproj:581`, `:626`, `:668`, `:692`, `:715`, `:738`, `:763`, `:795`); team supplied locally per developer machine.

## Declared but Unused

### `AppIntents.framework`

- **Linked to three targets:** the app, `fitbodTests`, and `fitbodUITests` (`fitbod.xcodeproj/project.pbxproj:78` declares the file ref; build-file entries at `:19–21`; included in the Frameworks build phases at `:137`, `:145`, `:153`).
- **No source use:** zero `import AppIntents` matches across `fitbod/` and `FitbodWidgets/`, zero `AppIntent` symbol references. The link is dormant — no shortcuts, no app-intent-driven widgets, no Siri integration.
- **Implication:** safe to remove if not on the near-term roadmap; or to keep as a placeholder for the AppIntents-driven controls that `CLAUDE.md` references for future iterations.

### App Group entitlement

- **Build setting:** `REGISTER_APP_GROUPS = YES` (`fitbod.xcodeproj/project.pbxproj:606`, `:651`).
- **Entitlements files (both):** no `com.apple.security.application-groups` key in `fitbod/fitbod.entitlements` (lines 1–11) or `FitbodWidgets/FitbodWidgets.entitlements` (lines 1–9).
- **Source use:** no `UserDefaults(suiteName:)` and no `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` calls anywhere.
- **Implication:** the build flag is on but the entitlement isn't wired and no code uses it. If you later need to share state (e.g., timer attributes) from the app into the widget via `UserDefaults` or a shared container, finish wiring this; today it's a no-op.

## Notable absences (verified by grep)

- **HealthKit / Apple Watch:** out — no imports, no `HKHealthStore`, no `WeightTrainingWorkout` types. Aligns with `CLAUDE.md` "out of scope".
- **CloudKit / iCloud:** out — no imports.
- **Combine:** not used in new code (no `import Combine` in app/widget source — the codebase relies on `@Observable` + `async`/`await`).
- **Networking:** zero `URLSession`/`URLRequest`. All "URL" matches in source are either local file URLs (e.g., `FileManager.url(for:)`) or `Bundle.url(forResource:)`.
- **Third-party SDKs:** none (see `STACK.md` for the empty SPM story).

---

**Confidence**

- **Direct-read (project.pbxproj, Info.plist, entitlements):** Live Activity wiring, AppIntents linkage, app-sandbox + app-group settings, UTI declaration, signing setup — every fact has a file path and line.
- **Direct-read (source greps):** import inventory, `UserDefaults` key inventory, OSLog subsystem/category strings, CryptoKit usage scope, the absence of HealthKit/CloudKit/Combine/URLSession.
- **Inferred:** that `AppIntents.framework` is a placeholder for future work (only the *absence* of code is direct-read; the *intent* is a guess). Same for the dormant `REGISTER_APP_GROUPS` flag.

*Integration audit: 2026-05-28*
