# Morrow (private journal) - Engineering Rules

## Product and scope
- Build a Flutter app for iOS and Android, branded "morrow": a simple, discreet personal tracker. Record bowel movements with optional plain-text comments, view/edit/delete entries, see simple trends, set local reminders, and optionally require device authentication.
- The shipped app is local-only. No accounts, backend, sync, analytics, advertising, remote crash reporting, runtime AI, or network-loaded assets.
- Treat entries, comments, timestamps, and database keys as sensitive. Use British English and synthetic data in code, tests, screenshots, designs, and AI prompts.
- This is a personal journal, not a diagnostic or treatment tool. Do not add medical interpretations or infer entries from notifications.
- Keep the morrow branding and the Figma theme (green and cream). The app must not advertise what it tracks: user-visible app name, launcher label, notifications, onboarding, and store-facing text use "morrow" and neutral wording ("entry", "log", "check-in"). Avoid bowel-related wording and imagery outside the entry page and its details sheet. Internal identifiers (package name, repository) may differ.
- Required vs optional: the only required parts of an entry are the entry itself and its date. Everything else is optional and skippable: the time of day, the note, Bristol stool type (1-7), ease, and circumstance tags (grouped as "Context" in the app). Saving with only a date must always work. Tapping "Add an entry" saves the entry immediately and opens its entry page: an entry for today records the current time; an entry for a past day selected in the week strip has no time (the user can add one). A rapid double tap must not create two entries, and the entry page offers Undo straight after creation. Entries without a time show "No time" and sort after timed entries on the same day. Symptoms are not recorded.
- Optional details visibility is controlled by two separate Settings toggles, both off by default: "Stool form" (Bristol stool type 1-7) and "Context" (ease and circumstance tags). A hidden detail is hidden everywhere (entry page, home list, history, trends). The note is always available. Turning a setting off hides its fields but must not delete stored values; deleting them is a separate explicit action. On the entry page each enabled detail has its own card (Context first, then Stool form); both open one shared sheet with a page per enabled detail, starting on the tapped card's page. The pages can be swiped between; the button reads "Next" except on the last page, where it reads "Done" (a single page has only "Done"). Each page has "Clear". Detail choices save as soon as they are picked, so closing the sheet any way keeps them. Pages don't label sections "Optional".
- One entry page for creating, viewing and editing (no separate detail and edit screens): it shows When, the enabled detail cards, the note and "Delete this entry". Everything on it saves as it is made (decided 9 November 2026): the note autosaves shortly after typing stops and when the app leaves the foreground, the date/time saves when its sheet is closed with Done, and details save as they are picked. The bottom button reads "Done" and returns to the journal; a small status above it says "Saved", "Saving…" or, after a failure, "Not saved yet" with "Try again". There is no discard prompt.
- Home journal is weekly: the home screen shows "This week's journal" (counts and list cover the current Monday-to-Sunday week) unless the user selects a specific day in the week strip, in which case it shows that day's journal. The week strip can be swiped (or stepped with previous/next buttons) back to earlier weeks, never past the current week; the counts and list then cover the week on screen. Future days can't be selected. Wording uses "this week", not "today".
- Trends and analytics: simple, descriptive, weekly summaries only (entries per week, weeks logged, average entries per week), computed on-device from stored entries, with 4, 12 and 26 week ranges. Do not focus on time-of-day or daily-rhythm patterns. No statistical modelling, forecasting, scoring, correlations, anomaly detection, "insights" or health advice. Stool form summaries appear only when the Stool form setting is enabled. Prefer drawing simple charts with Flutter's own widgets; ask before adding a charting dependency.
- Local backup and restore (in scope for v1): the user can export their entries to a backup file and restore from one, from Settings > Data & privacy and from the welcome screen on a fresh install. The app never talks to a cloud service: it hands the file to the OS share/save sheet (Files, Google Drive, iCloud Drive and similar) and reads a file the user picks with the OS file picker. Backups contain entries (date, time if recorded, note and optional details), not reminders, settings or app-lock state. Restore only adds entries: it skips entries already present, never overwrites or deletes existing ones, and reports how many were added and skipped. A backup file holds sensitive data, so proposed design: it is encrypted with a user-chosen passphrase using a maintained library (no custom cryptography); a forgotten passphrase cannot be recovered. Confirm the encrypted-backup decision, the backup file format/version and the dependencies (share, file picker, encryption) before building.
- Out of scope for v1: advanced analytics or modelling, cloud sync or direct cloud-service integration, accounts, medical interpretation, multiple reminders, CSV or other export formats, dark mode (planned after v1).
- Development-time package downloads and documentation access are separate from the no-network requirement for the shipped app.

## Working agreement
- Inspect the repository and existing decisions before changing code. Do not assume scaffolding, dependencies, or tests already exist.
- For substantial changes, give a small implementation plan, assumptions, risks, and acceptance tests before implementation.
- Work in small, reviewable changes. Avoid unrelated refactors and speculative features.
- Ask before adding unapproved dependencies, changing the security model, introducing network access, changing native permissions, or performing destructive operations. Backup/restore will need packages not yet approved (OS share/save, file picker, passphrase encryption); propose specific, maintained candidates and ask first.
- Verify APIs against the versions in pubspec.lock and their official documentation. Do not invent APIs or copy obsolete examples.
- Report exactly which checks ran, their results, and which device/platform checks remain unverified. Never claim security or production readiness without evidence.
- Never read, upload, log, or commit real journal exports, device databases, credentials, signing materials, or personal health data.

## Approved starting stack
- Flutter/Dart: compatible stable releases; record the toolchain and commit pubspec.lock.
- State/dependency injection: flutter_riverpod; use Notifier/AsyncNotifier where appropriate. Start without Riverpod code generation.
- Navigation: go_router, with a central application lock gate.
- Persistence: drift with its currently documented encrypted native SQLite setup; for the current setup this is sqlite3 with SQLite3MultipleCiphers.
- Keys and lock bootstrap metadata: flutter_secure_storage with explicit platform options.
- Optional device authentication: local_auth.
- Reminders: flutter_local_notifications, timezone, and flutter_timezone.
- App-private paths: path_provider where needed.
- Quality: flutter_lints, flutter_test, integration_test, drift_dev, and build_runner as required by Drift.
- Start with small immutable Dart models. Do not add Freezed, JSON serialisation, shared_preferences, a service locator, or another state library without a concrete need.
- Resolve compatible package/platform versions; do not automatically upgrade to every new major release.

## Architecture
- Organise by feature: journal, reminders, and settings. Put application composition, routing, and the lock controller under app/.
- Put database, key storage, authentication, and notification adapters under core/. Keep shared presentation components under ui/.
- Use this dependency direction: screen -> controller/view model -> repository -> database/platform adapter.
- A Riverpod controller is the feature's view model; do not add a duplicate view-model layer.
- Widgets must not access database handles, keys, or native plugins directly.
- Inject repositories, platform adapters, and the clock so tests can use fakes.
- Add interfaces at meaningful testing/platform boundaries, not for every class.
- Do not add a separate use-case/domain layer unless business complexity justifies it.
- All sensitive screens, routes, and data providers belong to an unlocked application scope. A route redirect alone is insufficient.

## Data and persistence
- Use neutral code naming for the entry model (`Entry`, not `PoopEntry`) so the codebase and generated schema do not spell out the subject.
- Entry has a local primary key, a stable uid, occurredAtUtc, originalUtcOffsetMinutes, hasTime (false when no time of day was recorded; occurredAtUtc is then midday on the entry's local day and is never shown), optional comment, optional stoolType (1-7), optional ease, optional circumstance tags from a small fixed set (no free text beyond the comment), createdAtUtc and updatedAtUtc. Confirm option lists against the Figma designs before changing the schema.
- Display preferences (show stool form, show context) are ordinary settings stored in the database, default off.
- Backup files carry a format version and are validated before import; restore runs in a transaction and is idempotent (duplicates are skipped by a stable entry identity). Test restore across schema versions.
- Choose and document historical date-grouping rules. Preserve the event's original local-day meaning when the device time zone changes.
- Store reminder intent separately: enabled, local weekday, local hour/minute, time-zone policy, and stable notification identifier.
- Keep the reminder requested by the user separate from observed OS permission/scheduling status.
- Persist ordinary settings in the database. Keep security bootstrap metadata outside it in secure storage so startup can decide whether authentication is required.
- Validate input, use parameterised queries, prevent double-submit duplicates, and report success only after persistence succeeds.
- Use transactions for related writes and explicit error states for failed saves. Do not silently discard drafts or overwrite records.
- Version the schema and test upgrades from every shipped schema. Never delete and recreate the database as an automatic migration recovery.

## Encryption and key lifecycle
- Encrypt the journal database even when optional app lock is disabled. Use a maintained encryption implementation; do not design cryptography.
- Generate a per-installation key with a cryptographically secure random source. Never hardcode it or derive it from device identifiers.
- Store keys only in platform secure storage. Configure non-synchronising, device-bound accessibility as supported; document exact platform behaviour.
- Verify the encryption-capable SQLite build and key setup before accessing data. Security checks must run in release builds, not only assertions.
- Test that the correct key opens the database and absent/wrong keys cannot read it. Inspect database companion files and temporary files for leaks.
- Existing database plus missing/unreadable key must enter a blocked error state, not create a replacement key or empty database. Key loss may be irreversible.
- Distinguish a genuine first install from a failed secure-storage read, interrupted setup, and restored/reinstalled state.
- This baseline uses OS-protected key storage plus an app authentication gate. A local_auth result does not cryptographically bind access to the database key.
- Authentication-bound Keychain/Keystore access is a separate security enhancement requiring an explicit design and native-device tests. Do not claim it is implemented unless verified.
- Do not promise protection against a compromised OS, forensic erasure, or guaranteed clearing of managed memory.

## Optional app lock
- Default to no additional app lock, with clear onboarding and a Settings option to enable it.
- Recommend OS biometrics with device-credential fallback, clearly labelled. Anyone with an accepted device credential can unlock the app.
- A biometrics-only policy requires an explicit product decision and a documented lockout/data-loss path. Never invent an app PIN fallback.
- Authenticate successfully before enabling lock; require authentication before disabling an enabled lock.
- Model uninitialised, locked, authenticating, unlocked, and error states explicitly. Do not persist an unlocked session.
- When enabled, require authentication on cold start and after actual backgrounding. Cover sensitive content as soon as the app becomes inactive.
- Treat the authentication prompt's own lifecycle changes separately to avoid endless re-authentication loops.
- Cancel or invalidate stale authentication results. An old successful callback must not unlock a newer locked/backgrounded session.
- Cancellation, lockout, unavailable credentials, or configuration errors must not silently disable an enabled lock.
- Open the journal only in an authorised session. On lock, close database access and dispose of sensitive providers, rendered content, and in-memory drafts according to the documented draft policy.
- Handle every notification launch and pending navigation through the same gate, including cold starts. Do not expose entries in route payloads.
- Protect app-switcher previews with platform-appropriate handling; test on physical devices. Do not claim all screenshots can be prevented.

## Local reminders
- Start with one optional weekly reminder (the user picks the day of the week and the time); no conditional reminders based on reading journal history in the background.
- Request notification permission when the user enables reminders, not automatically on first launch. Denial must not prevent journalling.
- Use OS scheduling, not Dart timers, continuous background services, push messaging, or periodic polling.
- Use generic content such as 'Weekly check-in' / 'Ready to add an entry?'. Never include comments, history, or bowel-related details in payloads.
- Use inexact Android scheduling. Do not add exact-alarm or battery-optimisation exemption permissions for this use case.
- Use a stable notification identifier. Reconfiguration must replace/cancel the previous schedule rather than accumulate duplicates.
- Initialise the time-zone database and obtain the device's zone; do not assume an offset is a time-zone identifier.
- Define reminders as local wall-clock times. Reconcile after time-zone changes/resume and document behaviour while the app remains closed.
- Configure and test Android reboot/update rescheduling without opening the encrypted journal or requiring authentication in the background.
- Schedule delivery independently of the journal's encryption key. Any OS/plugin schedule cache must contain no journal records.
- Handle foreground, background, and terminated launches; permissions revoked in Settings; battery restrictions; device restart; and Android Force Stop followed by reopening.
- Do not promise exact or guaranteed delivery. Reconcile desired settings with OS scheduling status and surface failures honestly.
- Disabling reminders and resetting the app must cancel pending and remove delivered app reminders as appropriate.

## Privacy, backup, and deletion
- Use app-private storage, not shared external storage or disposable cache folders for the primary database.
- Configure Android backup/transfer exclusions for supported OS versions, including plugin/secure-storage artefacts. Do not rely on allowBackup=false alone.
- Configure iOS backup exclusions and non-synchronising key accessibility. Document that OS backup-exclusion flags are not an absolute guarantee.
- Test backup, restore, transfer, reinstall, and key-loss behaviour. An unreadable restored database must fail safely without silent data replacement.
- Explain that there is no account recovery and data may be lost after uninstall, device loss, or key loss, and that the user's own exported backup is the only recovery route.
- Export and restore are limited to the local backup flow described under Product and scope. Exported files leave app-private storage once the user saves them, so say so plainly, never write them to shared storage without the user choosing the location, and never log or retain a copy. Test export/restore on physical devices with real OS share sheets and file pickers; mocks are not evidence.
- Never log records, comments, timestamps, keys, SQL bound values, or sensitive exception payloads. Diagnostics must be redacted and local.
- Use minimal permissions and bundled assets. Audit merged release manifests and SDK behaviour for unexpected network access and permissions.
- Implement explicit Delete all data confirmation. Re-authenticate when app lock is enabled; close database handles, cancel reminders, remove database/companion/cache files, and delete app keys/settings.
- Make interrupted deletion recoverable without revealing data. Offer destructive reset for irrecoverable key loss only with explicit acknowledgement, never automatically.

## UI and accessibility
- Use Figma for the journal list, entry page and details sheet, history, trends, privacy, Settings/reminders, and lock/error states, following the existing morrow theme. Use synthetic content only. Design file: https://www.figma.com/design/k5nqDgD29IrWJ3nuKYdOLS/poopTracker
- The Figma page has two columns: every approved design on the left, integrated into the journey sections (0-9) whether built or not, and superseded screens ("Old · ...") and rejected drafts on the right. When a new design is approved, merge it into its journey and move the frames it replaces to the right. Build status lives in docs/design-catalogue.md.
- Designs must show the default state (both optional-detail settings off) as the primary state; the enabled state is a variant. The Figma file is organised by journey (sections 1-9), numbered in the order a person meets the screens; "Details on" screens show both settings on.
- Implement reusable theme tokens and standard Flutter controls rather than copying generated layout code wholesale.
- Support large text, screen readers, contrast, and keyboard insets. Do not communicate state by colour alone.
- Dark mode is planned for after v1 (no dark designs yet). Keep colours in theme tokens, never hard-coded in widgets, so a dark palette can be added later without rework.
- Provide loading, empty, saving, success, permission-denied, locked, and error states as applicable.
- Use plain-text comments with a documented length limit. Define what happens to an unsaved draft when the app locks.

## Verification and completion
- Unit-test validation, date grouping, reminder reconciliation, repository logic, and every lock-state transition using an injected clock/fakes.
- Widget-test entry editing, failed saves, duplicate taps, accessibility, and absence of sensitive content while locked.
- Database-test persistence after reopen, transactions, deletion, and migrations using real temporary databases.
- Run encryption and native-plugin tests against actual Android/iOS builds; mocked success is not evidence of native security.
- integration_test covers Flutter journeys but not all native system UI. Use documented manual device checks or separately approved native-aware test tooling for biometrics/permissions/notifications.
- Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test` before reporting a change complete, where tooling is available.
- When schema/code generation changes, run `dart run build_runner build` and verify generated output before analysis/tests.
- Run relevant device integration tests separately; never imply `flutter test` exercised native permission dialogs or biometric hardware.
- Review dependency advisories, maintenance, licences, and native dependencies. `flutter pub outdated` is an update check, not a security audit.
- Do not suppress warnings, disable checks, weaken encryption, or delete tests to obtain a passing build.
- Summarise changed files, behaviour, test evidence, remaining risks, and required physical-device checks.
