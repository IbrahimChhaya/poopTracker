# morrow — implementation plan

Status: approved 7 November 2026, with the section 2 defaults accepted and dark mode moved to after v1. M0 to M3 are done (M3's iOS device check is still open). M4 is done. M5 is built and awaiting review.
Source of truth for rules: `CLAUDE.md`. Source of truth for screens: the Figma file, sections 1–9.

## 1. Starting point

- Flutter 3.47.9 (stable), Dart 3.13.7, SDK at `C:\src\flutter` (on the user PATH). Android SDK at `C:\Android\Sdk`, JDK OpenJDK 24.0.1.
- Project created with `flutter create` (Android + iOS only). `lib/main.dart` is still the counter demo.
- IDs: Android `com.chhaya.poop_tracker`, iOS `com.chhaya.poopTracker`, iOS deployment target 15.0.
- Dependencies today: `flutter`, `cupertino_icons`, `flutter_test`, `flutter_lints`.

### Versions that resolve today (dry run only, nothing added)

| Package | Resolves to | Notes |
|---|---|---|
| flutter_riverpod | 3.5.0 | Notifier / AsyncNotifier, no codegen |
| go_router | 18.1.3 | |
| drift / drift_dev | 2.35.3 / 2.35.2 | |
| sqlite3 | 3.9.0 | Bundles SQLite through build hooks |
| sqlite3_flutter_libs | 0.6.0+eol | **End of life — do not add.** Use sqlite3 3.x hooks instead |
| flutter_secure_storage | 11.2.0 | |
| local_auth | 3.0.2 | |
| flutter_local_notifications | 23.0.0 | |
| timezone / flutter_timezone | 0.11.2 / 5.1.1 | |
| path_provider / path | 2.1.6 / current | |
| build_runner | 2.17.1 | dev |
| integration_test | SDK | dev |

Before adding each package: read its current docs and changelog for that exact version, check advisories, licence and maintenance, then commit `pubspec.lock`.

## 2. Decisions needed before or during the build

Each has a proposed default. Milestones that depend on it are listed in brackets.

1. **Encrypted backups.** Default: yes. The passphrase is at least 8 characters and can't be recovered. [M11]
2. **Week start.** Default: Monday to Sunday everywhere (week strip, "this week", trends), not locale-dependent. [M2]
3. **Draft policy when the app locks.** Default: an unsaved new or edited entry is discarded when the app locks. The editor says so in small print. [M8]
4. **Symptom severity.** The Entry detail design shows "Bloating · Mild", but the context step has no way to choose a severity. Default: drop severity and store symptoms only. [M6]
5. **"None" symptom chip.** Default: stored as an explicit "no symptoms" answer, exclusive with the others. It counts as "no symptoms recorded" in trends, the same as not answering. [M6, M7]
6. **Future-dated entries.** Default: not allowed beyond the current time. Any past date is allowed. [M2]
7. **Dark mode.** Decided: after v1. v1 ships light only, with every colour in theme tokens so a dark palette can be added later. [M1]
8. **"Optional" tags on Entry detail and Trends.** Default: keep them as designed. [M6, M7]
9. **New dependencies for backup.** These need approval: share/save (proposed `share_plus`), file picking (proposed `file_picker`) and encryption (proposed `cryptography`: Argon2id key derivation and AES-GCM). Versions will be checked when approval is requested. [M11]
10. **Native and permission changes.** These are expected and each needs approval when its milestone starts:
    - `MainActivity` becomes `FlutterFragmentActivity` (local_auth).
    - `USE_BIOMETRIC`.
    - `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` (reminders).
    - iOS `NSFaceIDUsageDescription`.
    - Android backup and data-extraction rules.
    - iOS backup exclusion (a small platform channel).
    - App-switcher protection on both platforms. [M3, M8, M9, M10]

## 3. Architecture

```
lib/
  main.dart                  bootstrap only
  app/                       composition, routing, lock gate, shell
    app.dart, router.dart, bootstrap/, lock/
  core/
    clock.dart               injectable Clock
    database/                drift schema, migrations, encrypted open, key bootstrap
    security/                secure storage adapter, key manager, auth adapter
    notifications/           notification + timezone adapter
    backup/                  backup codec, crypto adapter, file adapter (M11)
  features/
    journal/                 models, repository, controllers, screens (home, add/edit, history, detail)
    trends/                  weekly summaries, screens
    reminders/               reminder intent, reconciliation, screens
    settings/                settings, data & privacy, delete-all, backup screens
  ui/                        theme tokens, shared widgets (cards, rows, sheets, dialogs, toasts, empty/error states)
```

- **Dependency direction:** screen → Riverpod controller (the view model) → repository → database or platform adapter. Widgets never touch database handles, keys or plugins.
- **Interfaces only at real boundaries:** `Clock`, `KeyStore`, `Authenticator`, `NotificationScheduler`, `BackupFileAdapter`, `BackupCrypto`. Tests use fakes.
- **Unlocked scope:** the journal database, repositories and all sensitive providers live in a nested `ProviderScope` created only when the lock controller is `unlocked`. Locking disposes that scope, which closes the database and drops cached entries and drafts. The router redirects to the lock screen as well, but the scope is the real control.

## 4. Data model (schema v1)

Times are stored as UTC milliseconds plus the original offset. The local day is `occurredAtUtc + originalUtcOffsetMinutes`, so an entry keeps its original calendar day if the phone's time zone changes later.

- `entries`
  - `id` (int primary key)
  - `uid` (text, unique, random v4 from `Random.secure`, used to spot duplicates on restore)
  - `occurred_at_utc`, `original_utc_offset_minutes`
  - `comment` (nullable, at most 500 characters counted as user-perceived characters, trimmed; empty becomes null)
  - `stool_type` (nullable, 1–7)
  - `ease` (nullable: easy / some_straining / difficult)
  - `created_at_utc`, `updated_at_utc`
- `entry_symptoms` (`entry_id`, `code`): none, bloating, cramping, urgency, mucus, blood. "none" can't be combined with the others.
- `entry_tags` (`entry_id`, `code`): after_meal, coffee, stress, low_fluids, medication, exercise.
- `app_settings` (single row): `show_stool_form`, `show_context`. Both default to false.
- `reminder` (single row):
  - `enabled`, `weekday` (ISO 1–7), `hour`, `minute`
  - `tz_policy` ('follow_device')
  - `notification_id` (a constant)
  - The OS permission and scheduling status are observed at runtime, not stored as if they were true.

Outside the database, in secure storage: the database key, a setup marker (`creating` / `ready`) and `app_lock_enabled`.

Rules:
- Every write goes through a repository. Related writes (an entry plus its symptoms and tags) use one transaction.
- Saving is guarded against double taps (an in-flight flag plus a disabled button). Success is reported only after the commit.
- Migrations are versioned. Never delete and recreate the database.

## 5. Milestones

Each milestone is one reviewable change. Each ends with `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and `dart run build_runner build` when the schema changes. The report for each milestone says what ran and what still needs a device.

### M0 — Project hygiene
- **Scope:**
  - User-visible app name "morrow" on Android (`android:label`) and iOS (`CFBundleDisplayName`).
  - Remove the counter demo and use a placeholder home.
  - Stricter lints on top of flutter_lints.
  - Record the toolchain in README.
  - Clear the pubspec description.
- **Accept when:** the app builds for Android (debug), shows "morrow" in the launcher, and checks pass.

### M1 — Theme and UI kit
- **Scope:**
  - Tokens from Figma: background #f7f4ec, card #fffdf8, line #dddcd0, ink #293b34, muted #74796d, primary #3d6552, tint #e7ede2, sand #f2e6da and danger.
  - Inter type scale and radii (12/14/16/20/99).
  - Light theme only. No hard-coded colours in widgets, so dark mode can follow after v1.
  - Shared widgets: setting row, card group, primary/secondary/danger buttons, chips, sheet, dialog, toast, empty/error/loading states, week strip, bottom navigation shell.
- **Risk:** Inter must be bundled as an asset. Network-loaded fonts are not allowed.
- **Accept when:** widget tests pass at 200% text scale, semantics labels exist, and contrast is at least 4.5:1 for body text (checked with a small test helper).
- **Built (7 November 2026), decisions made while building:**
  - Muted text is `#666b60` (5.0:1 on background, 4.6:1 on tint), not Figma's `#74796d` (4.07:1). `#74796d` stays for icons and chevrons. Figma text fills were updated to match.
  - Labels on disabled buttons ("Saving…") use `#595e53` (4.8:1 on `#dcdcd2`).
  - Week strip cells keep the Figma look, but each tap target is a full seventh of the row (at least 48 px on a 402 pt phone).
  - Icons use the nearest Material outlined icons. Figma uses Lucide; adding a Lucide package would need approval.
  - Inter 4.1 static TTFs are bundled from the official rsms/inter release, with the OFL registered in the app's licences page.
  - A debug-only UI kit preview opens from the placeholder Settings tab.
  - Warm accent split in two: `warmIcon` `#ac7157` for icons and the stool form illustration (3:1 is enough), and `warmText` `#895943` for small text (4.8:1 on sand, 5.8:1 on card). Figma's "TYPE n" labels went from 10 to 11 pt.
  - Switches follow the Material 3 pattern. Off is a light track (`#ece9df`) with a 2 px `#74796d` outline (4.4:1 on card) and a small dark thumb. On is a primary track with a large cream thumb and a check mark. Figma switches were updated to match.

### M2 — Models and pure logic
- **Scope:**
  - Immutable `Entry`, `Ease`, `Symptom`, `Tag` and validation.
  - Local-day and Monday-week maths.
  - Grouping for history.
  - Weekly summaries for 4/12/26 weeks: entries per week, average, weeks logged, stool form counts, symptom counts.
  - "Not enough data" rule: entries in fewer than two distinct weeks.
  - `Clock` abstraction.
- **Accept when:** unit tests cover the comment limit, stool range, future dates, "none" exclusivity, grouping across a time-zone change and across the UK DST changes, week boundaries, and every summary figure in the Figma Trends screens reproduced from synthetic fixtures.
- **Built (7 November 2026), decisions made while building:**
  - Stool form is summarised as counts per type only. The "72% were type 3 or 4" headline and the "Types 3–4: formed stools" note were removed from Figma 5.4–5.6, because singling out a range is a medical interpretation. All bars with entries now share one colour.
  - Notes are limited to 500 user-perceived characters using the `characters` package (Dart team, BSD-3, already pinned by the Flutter SDK at 1.4.1; now a direct dependency).
  - Future times: anything more than 1 minute after now is rejected. UTC offsets must be between -12:00 and +14:00.
  - Date grouping rule: an entry's local day and clock time come from its UTC instant plus the offset recorded with it. Entries never move when the phone changes zone. "Today" and "this week" use the phone's current offset. Within a day, entries are ordered by when they really happened.
  - Averages divide by every week in the range, including empty weeks and the week in progress. They are rounded half up to one decimal place using whole-number maths.
  - Labels (British English, no localisation package): "Today · 6 Nov", "Wednesday · 6:20 pm", "12 Oct – 8 Nov 2026", "Friday, 6 November 2026".
  - `Clock` reports UTC plus the current offset, because Dart tests cannot change the device's time zone. Real time zone and clock changes still need a device check.
  - Figma inconsistencies, not reproduced: the journal week strip shows dots on Monday and Tuesday although that week's five entries are Wednesday to Friday, and History shows "18 entries" for 24 Oct – 6 Nov although the Trends weeks put fewer entries in that span.

### M3 — Encrypted database and key bootstrap
- **Scope:**
  - drift schema v1 on `sqlite3` 3.x, with SQLite3MultipleCiphers selected through the package's build-hook configuration (confirm the exact pubspec setting in the sqlite3 and drift docs).
  - Open with `PRAGMA key` as the first statement.
  - Verify the cipher build and that the key works before any query, in release builds too.
  - Key generation (32 bytes from `Random.secure`) and explicit flutter_secure_storage options:
    - iOS: this-device-only, non-synchronising keychain accessibility.
    - Android: options chosen from the v11 docs.
  - Startup state machine: first install, setup interrupted, ready, key missing with an existing database (blocked, screen 8.8), secure-storage read failure (blocked), and a restored or reinstalled state.
- **Native:** none yet.
- **Accept when:** real temporary-database tests show:
  - The correct key opens the database.
  - A wrong or missing key fails and never creates a replacement.
  - No plaintext appears in the database, `-wal`, `-shm` or journal files (byte scan for a synthetic marker string).
  - Reopening keeps the data.
  - Transactions roll back on failure.
- **Device:** confirm the encrypted build on a physical Android and iOS device. A host test is not proof of the native build.
- **Built (7 November 2026):** see [security.md](security.md) for the full design.
  - `pubspec.yaml`: `hooks: user_defines: sqlite3: source: sqlite3mc`. Cipher `chacha20`, key via `PRAGMA hexkey`.
  - flutter_secure_storage: Android `resetOnError: false` (the plugin default would wipe the key on a read error), ciphers pinned. iOS `unlocked_this_device`, not synchronisable.
  - Reinstall decision: a stored key with no journal file is discarded and setup starts fresh.
  - CHECK constraints are table-level SQL (`customConstraints`), because drift's self-referencing `.check()` trips the `recursive_getters` lint.
  - Schema v1 is exported to `drift_schemas/journal/drift_schema_v1.json` for future migration tests.
  - A minimal `EntryRepository` (create, update, delete, list, watch) is included so persistence and transactions are tested now.
  - Diagnostics: Settings > Developer > Encryption self-check, in debug builds or with `--dart-define=MORROW_DIAGNOSTICS=true`.

### M4 — App shell, routing and the unlocked scope
- **Scope:**
  - The bootstrap gate (loading, blocked, erase-and-start-fresh with an acknowledgement checkbox).
  - go_router with the bottom-navigation shell (Journal, History, Trends, Settings).
  - The nested unlocked `ProviderScope`.
  - Lock controller with app lock off: always unlocked after bootstrap.
- **Accept when:** widget tests show no sensitive provider can be read outside the unlocked scope, and that the blocked state never offers to create a new journal automatically.
- **Built (7 November 2026), decisions made while building:**
  - Gate order: lock gate, then the journal is opened or created (only in an unlocked session), then the unlocked scope.
  - The gate screens (loading, locked, blocked) use their own plain `MaterialApp`. The journal app and its go_router exist only inside the unlocked scope and are rebuilt for each session.
  - Sensitive providers (`appDatabaseProvider`, `entryRepositoryProvider`) declare `dependencies`, so Riverpod treats them as scoped. Read anywhere else they throw `OutsideUnlockedScopeError`.
  - The journal session provider is auto-disposed and closes the database when nothing watches it. Riverpod 3's automatic retry is turned off for it, so a blocked journal waits for the user.
  - "Erase and start fresh…" is offered only when a journal exists but can't be opened (key missing or rejected, unencrypted or unreadable file, or a failed erase). Storage, encryption-build and setup problems offer "Try again" only.
  - Erasing deletes the database files first and the key last, so an interrupted erase is safe.
  - The lock controller has every lock state but always returns `unlocked` until M8. Its state enum is `AppLockState`, because Flutter already has a `LockState`.
  - Device evidence: `integration_test/startup_test.dart` passed on the S20. A real start reached the shell, and a second start reopened the same journal (`createdNew: false`).

### M5 — Journal, logging and history (optional details off)
- **Scope (Figma 1.4, 2.1–2.7, 4.1–4.11):**
  - Home: weekly counts, this week's journal, day selection, today outlined.
  - Add entry: date/time sheet, note limited to 500 with a counter, saving, save failed with the draft kept, discard confirmation, saved toast.
  - History: grouped by day, search inside notes, date filter.
  - Empty states, entry detail, edit, delete confirmation, deleted toast.
- **Accept when:**
  - Widget tests cover a failed save keeping the draft, double tap creating one entry, discard, edit, delete, search with no results, and day selection.
  - The integration test add → edit → delete passes on an Android emulator.
- **Built (7 November 2026), decisions made while building:**
  - Home stats cover the week on screen (the current week unless paged back). "Most recent entry" shows a time if the entry was today, otherwise a relative day ("Yesterday", "Wednesday", "30 Oct"). Tapping a day shows that day's journal, and tapping it again returns to the week. The trend preview appears only when the last 4 weeks have entries.
  - The editor is a full-screen route above the tabs, and entry detail sits inside its tab. Entry ids travel as in-memory route data (`extra`), never in route paths.
  - Saving is guarded by an in-flight flag plus a busy button. Success is reported only after the commit. A failed save keeps the draft and offers "Try again".
  - Editing keeps optional details not shown in the editor (stool form and context), and keeps the original instant and time-zone offset unless the time is changed.
  - Future times can't be chosen in the time sheet, and are also rejected on save.
  - History: search matches notes (case-insensitive) within the chosen range. Ranges are last 2 weeks (the default), last 4 weeks, last 3 months and all time. "Show earlier entries" steps to the next wider range.
  - The delete dialog uses the Figma order, with a filled danger "Delete entry" first. Discard dialogs keep the safe choice first.
  - The week strip now uses `LocalDate`.
  - Small deviations from Figma: the note counter sits under the field, not inside it, and the "Other date" chip shows the chosen date.
  - Feedback round (7 November 2026):
    - The week strip swipes back through earlier weeks (up to about ten years), never past the current week. Previous and next week buttons and a week label do the same without gestures.
    - The list and the stats card follow the week on screen ("This week's journal" or "Week of 26 Oct"; "Logged this week" or "Logged 26 Oct – 1 Nov"). "Most recent entry" is the latest entry in that week.
    - The pager runs oldest to newest, because a reversed `PageView` jumped to the wrong week when a day was scrolled into view, for example by a screen reader.
    - Future days are muted, can't be tapped, and are announced as "not available yet".
    - A selected past day becomes the new entry's default date, at the current time of day. That isn't treated as a change, so closing needs no confirmation.
    - The "On-device only" chip is removed from the journal home.
    - Copy: the home title is "Your journal" (was "A little daily clarity."), and the trend link is "See your patterns" (was "Your patterns, coming into focus").
    - Figma was updated to match (see the M5 Figma note below).
  - **Figma updated (7 November 2026):**
    - Journal frames 1.4, 2.1, 2.7, 3.4 and 4.1: the "On-device only" chip is removed, the title is "Your journal", and the link reads "See your patterns". A week header ("‹ This week ›", with › disabled) sits above the strip, and Saturday and Sunday are muted as future days. The stray entry dots on Monday and Tuesday are removed, so the strip matches the five Wednesday-to-Friday entries.
    - New frame 4.12 "Journal · Earlier week" shows the week of 26 October with its own counts ("Logged 26 Oct – 1 Nov") and the "Week of 26 Oct" list.
    - Editor frames 2.2–2.6, 3.1 and 4.9: the character counter now sits under the note box, as in the app.
    - Read me: notes the week strip's earlier weeks and the unavailable future days.
    - Time sheet: the highlight is now drawn behind the wheels. `CupertinoPicker` paints its selection overlay on top of the items, which hid the chosen time. Checked with a screenshot on the S20.
  - Draft policy on lock: drafts already live only in the unlocked scope, so they're discarded on lock. The small-print note in the editor comes with app lock in M8.
  - Device evidence, S20 (Android 13): `integration_test/journal_flow_test.dart` (add, edit and delete, against the real encrypted database in a temporary folder with an in-memory key store) passes, along with the startup and self-check tests. The test registers Flutter's test keyboard, because with the real keyboard attached the phone sent back stale text and overwrote the edit.

### M6 — Optional details
- **Scope (3.1–3.4, 4.3, 4.8, 8.2):**
  - Two Settings toggles.
  - Optional stool form step and "A little context" step, each skippable, with the step count adapting.
  - Details shown in the journal, history and detail screens only when their setting is on.
  - Turning a setting off hides values but keeps them.
- **Accept when:** tests cover all four on/off combinations, values surviving off → on, and that the default build shows no stool or symptom wording anywhere in the main flows.

### M7 — Weekly trends
- **Scope (5.1–5.7):** 4/12/26-week ranges with previous/next navigation, summary tiles, weekly bar chart (Flutter widgets or CustomPaint), stool form and symptom sections behind their settings, not-enough-data state, and no health advice.
- **Accept when:** golden-free widget tests check the figures against M2 fixtures, and the bars have semantic labels such as "Week of 2 Nov, 5 entries".

### M8 — App lock
- **Scope (1.2, 1.3, 7.1–7.6):**
  - local_auth adapter, biometrics with device-credential fallback.
  - Lock states: uninitialised, locked, authenticating, unlocked, error.
  - Authenticate before turning the lock on or off.
  - Lock on cold start and after real backgrounding, ignoring the auth prompt's own lifecycle changes.
  - A session token so stale callbacks are rejected.
  - Locking disposes the unlocked scope and applies the draft policy.
  - Privacy cover while inactive.
  - Cancellation or lockout never turns the lock off.
- **Native:** `FlutterFragmentActivity`, `USE_BIOMETRIC`, `NSFaceIDUsageDescription`, and app-switcher protection (Android recents screenshot setting, iOS cover view). These need approval.
- **Accept when:** unit tests cover every state transition and a stale-callback test passes with a fake authenticator and fake clock. Manual checks on physical devices: Face ID or fingerprint, passcode fallback, lockout, app-switcher preview.

### M9 — Weekly reminder
- **Scope (6.1–6.5):**
  - Reminder intent stored in the database.
  - Permission requested only when the reminder is switched on; denial leaves journalling untouched.
  - `zonedSchedule` with a weekly match and inexact Android scheduling, a stable ID, and replace-not-add on change.
  - Time-zone database initialised and the device zone read through flutter_timezone.
  - Reconcile on resume and on time-zone change.
  - Generic copy only ("Weekly check-in" / "Ready to add an entry?") with no payload data.
  - Tapping the notification goes through the lock gate.
  - The plugin's boot receiver reschedules without opening the journal.
- **Native:** `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` and the plugin receivers. No exact-alarm or battery-exemption permissions.
- **Accept when:** reconciliation unit tests pass for a time-zone change, permission revoked and a duplicate-schedule guard. Manual device checks: delivery, reboot, Force Stop then reopen, permission revoked in system Settings, battery saver.

### M10 — Data & privacy and Delete all data
- **Scope (8.1, 8.3–8.9):**
  - Settings and Data & privacy screens.
  - Delete all data with an acknowledgement checkbox and re-authentication when the lock is on. It closes the database, cancels the reminder and removes delivered notifications, deletes the database, companion and cache files, then keys and settings, with markers so an interrupted delete can resume.
  - Android backup and data-extraction exclusions, including secure-storage files.
  - iOS backup exclusion on the database directory.
- **Accept when:** tests cover an interrupted deletion resuming and nothing remaining afterwards (file listing in tests). Manual device checks: Android backup/transfer and iOS backup and restore show the blocked state, not silent data replacement.

### M11 — Backup and restore (needs decision 1 and dependency approval)
- **Scope (9.1–9.10, Welcome "Restore from a backup"):**
  - Versioned JSON payload built with `dart:convert` (no codegen), encrypted in memory with Argon2id and AES-GCM.
  - Export hands the encrypted file to the OS save sheet; no plaintext file ever touches disk, and the temporary encrypted file is deleted afterwards.
  - Restore: pick file → passphrase → validate version → one transaction that adds only, skipping known `uid`s → report added and skipped counts.
  - A wrong passphrase or foreign file changes nothing.
- **Accept when:**
  - Round-trip tests pass.
  - Tampered and wrong-passphrase tests fail safely.
  - Restoring twice is idempotent.
  - Restore into a non-empty journal works.
  - Restoring a backup made with an older schema works.
  - Manual device checks: Files, Google Drive and iCloud Drive with real system sheets.

### M12 — Hardening and release readiness
- **Scope:**
  - Accessibility pass: TalkBack, VoiceOver, large text, contrast, keyboard insets.
  - Merged-manifest and Info.plist audit.
  - A check that release builds make no network calls.
  - Licence and advisory review.
  - Launcher icon, using neutral imagery.
  - Store-facing text in neutral wording.
  - Written device test checklist with results.
- **Accept when:** the checklist is complete on at least one physical Android device and one iPhone. Nothing is called production-ready without that evidence.

## 6. Main risks

- **Encrypted SQLite build:** the setup changed with sqlite3 3.x, and `sqlite3_flutter_libs` is EOL. Wrong configuration silently gives an unencrypted database. Mitigation: a runtime cipher check plus a byte-scan test, and a device check in M3.
- **Secure storage and restore:** behaviour differs by OS version and backup path. Mitigation: explicit options, the blocked state and device restore tests (M3, M10).
- **App-switcher protection and lifecycle timing:** these need native work and can't be fully proven in `flutter test`. Mitigation: manual device checks in M8.
- **Reminder reliability:** inexact scheduling and vendor battery policies mean delivery is never guaranteed. The UI shows the real status and never promises delivery.
- **Backup passphrase loss:** irreversible by design. The UI makes this clear before creating a backup.
- **Dark mode after v1:** keeping every colour in tokens now avoids rework later.
- **Figma figures are synthetic:** tests reproduce them from fixtures, never from real data.

## 7. Checks that will always need a physical device

Encrypted database on the native build, biometrics and passcode fallback, lockout, app-switcher previews, notification permission dialogs, reminder delivery, reboot, Force Stop, battery saver, OS backup/restore/transfer and reinstall, system save sheets and file pickers for backups, and screen readers. `flutter test` and emulators don't prove any of these.
