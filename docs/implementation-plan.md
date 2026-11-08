# morrow — implementation plan

Status: approved 7 November 2026, with the section 2 defaults accepted and dark mode moved to after v1. M0 to M6 are done (M3's iOS device check is still open). M6.1 is done. M6.2 (journal polish from the design critique) is done; M6.3 (one-tap entry and one entry page) is built and checked on the S20; TalkBack and iOS checks remain. M7 (weekly trends) is built and awaiting review. M7.5 (diagnostics log) is built and checked on the S20. M8 (app lock) is built and checked on the S20; iOS and lockout checks remain. M9 (weekly reminder) is built and checked on the S20; delivery and reboot checks remain.
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
| flutter_local_notifications | 22.3.3 | 23.0.0 needs AGP 9.1.1 and compileSdk 37; upgrade in M12 |
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
4. **Symptom severity.** *Superseded, 8 November 2026:* symptoms are no longer recorded (see M6.1).
5. **"None" symptom chip.** *Superseded, 8 November 2026:* symptoms are no longer recorded (see M6.1).
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
  - `has_time` (v2, default true). When false, `occurred_at_utc` is midday on the local day and is never shown.
  - `comment` (nullable, at most 500 characters counted as user-perceived characters, trimmed; empty becomes null)
  - `stool_type` (nullable, 1–7)
  - `ease` (nullable: easy / some_straining / difficult)
  - `created_at_utc`, `updated_at_utc`
- `entry_tags` (`entry_id`, `code`): after_meal, coffee, stress, low_fluids, medication, on_period, feeling_sick (v2; `exercise` was removed).
- Schema v2 (M6.1): adds `has_time`, drops `entry_symptoms`, and changes the tag list. It's an exported step-by-step migration, tested from v1.
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
- **Built (8 November 2026), decisions made while building:**
  - Settings > Journal has the "Stool form" and "A little context" switches, stored in the `app_settings` row and both off by default.
  - The editor is the hub (3.1). With a setting on, an "Optional details" card shows a row per enabled step with its current value ("Not set", "Type 4 · Smooth and soft", "Easy · No symptoms · Coffee"). A row opens its step.
  - Steps (3.2, 3.3): the count adapts ("1 OF 1" with one setting on). Each step can be skipped ("Skip", "Skip and save entry"), and tapping a chosen type or chip again clears it. Only the stool form eyebrow says "OPTIONAL"; the context step says it once, in its first line. Saving from a step closes the steps and the editor.
  - Symptoms: "None" and other symptoms clear each other. No severity (decision 4): Figma's "Mild bloating" and "Bloating · Mild" now read "Bloating". "Optional" labels stay on Entry detail (decision 8).
  - Cards (3.4, 4.3) show the type tile, "form · ease", and a symptoms line ("No symptoms" for an explicit None; nothing when unanswered). With no details shown, the card falls back to the note.
  - History has an "All types" filter while stool form is on. The filter is ignored while it's off, so hidden values never filter entries invisibly.
  - Stool drawings are simple shapes painted by Flutter (no image assets), decorative and excluded from semantics.
  - Turning a setting off hides its details everywhere, keeps stored values, and an edit made while they're hidden keeps them (tested). Deleting stored details is a separate action, not built yet.
  - The default-build check: with both settings off, no stool or symptom wording appears in the journal, editor, entry detail or History, including in screen-reader labels (tested).
  - Device check, S20: Settings switches, the editor hub and both steps were screenshotted and look right.

### M6.1 — Optional time and the 8 November design pass
- **Scope:**
  - Catalogue every Figma frame and record the changes (see [design-catalogue.md](design-catalogue.md)).
  - Apply the design changes.
  - Make the time of day optional.
  - Remove symptoms.
  - Change the tag list.
- **Built (8 November 2026):**
  - **Optional time.** `has_time` flag. Date-only entries are stored at local midday and never shown. Today defaults to now; a past day (Yesterday, Other date, or a day selected on the journal) defaults to no time.
    - The time sheet has a "Record a time" switch, and the whole row toggles it. Until the user flips it, picking today turns it on and picking a past day turns it off.
    - Untimed entries show "Yesterday" on journal cards, "No time" in History and day lists, "Yesterday · No time" in the editor, and "No time recorded" on entry detail.
    - Within a day they sort after timed entries.
    - A date-only entry for today is never "in the future"; tomorrow is.
  - **Symptoms removed** everywhere: the context step, cards, entry detail, the trends model, the schema and Figma.
  - **Tags:** "Exercise" removed; "On my period" and "Feeling sick" added.
  - **Design pass applied:**
    - Stool step: no eyebrow or back arrow; "Choose the closest match"; Continue (or Done) only.
    - Context step: back arrow and Skip; no "optional" line and no footer.
    - History: no eyebrow, subtitle or count line ("0 entries" still shows when nothing matches).
    - Entry detail: no "Optional" labels and no "Saved on this device" line.
    - Journal: shorter empty message.
    - Settings: the "A little context" description is updated.
    - The step count is now carried by the progress bar's screen-reader label ("Step 1 of 2").
  - **Migration:** drift `stepByStep` from the exported v1 and v2 schemas. The test covers a schema match plus data: an entry kept, `has_time` true, symptoms gone, `exercise` removed and `coffee` kept, new codes accepted. On the S20 the real v1 dev journal migrated, and the startup and add/edit/delete integration tests pass.
  - **Figma:** symptoms and Exercise removed from 3.3, 3.4, 4.3, 4.8 and 5.4–5.6. The 2.3 sheet has a "Record a time" row. New frame 2.8 shows a past day with no time. Yesterday's sample entry is untimed in the journal and History frames. The Read me is updated.
  - **Device test runs:** run integration tests with `flutter test integration_test/<file> -d <device> --no-uninstall`. Without the flag, flutter_tools uninstalls the app after the run, which deletes the dev journal and its Keystore key. This happened once after the M6.1 runs; the migration was not at fault.
- **CLAUDE.md updated:** the date is the only required part; the time defaults; no symptoms; skippable steps without "Optional" labels; trends show stool form summaries only.

### M6.2 — Journal polish from the design critique (done)
- **Source:** an `/impeccable critique` of `lib/features/journal` on 8 November (27/40), with the fixes mocked in Figma section 10 ("Critique pass") and approved before building.
- **Stat card:** values at 20 px (was 25), 14 × 18 px padding. At text scales above 1.15 the two figures stack with a horizontal divider, so a value never wraps away from its unit ("2 / entries" at 130% before).
- **Journal home:** tighter spacing above the list (brand to title 16, date to week 20, week to stats 12, button to list 20), so the first entry shows sooner.
- **Entry cards:** no "No note" line; a card with neither a note nor shown details is a single line. In day-grouped lists (History, a selected day) an untimed entry is titled "Entry" instead of "No time". The screen-reader label drops the summary too.
- **Entry detail:** title at the headline size (20 px), the rule for screens you navigate into ("New entry" already used it). The time leads in 27 px, then the date in sentence case in Muted Text; a date-only entry leads with the date and "No time recorded". The Sand date card is gone; Sand now frames only the stool form panel (Warm Edge rule). The "Ease of passage" value wraps instead of overflowing at 200%.
- **Docs:** DESIGN.md and `.impeccable/design.json` updated (stat value, title rule, sentence case now has one exception, entry card content).
- **Tests:** 297 pass, including new stat-card layout tests at 100% and 130%. On the S20: journal at 100/130/200%, History, and timed and untimed detail checked. Not checked on the device: the details-on detail screen (stool form panel), covered by the 200% widget test only.
- **Not changed:** the entry counts beside "This week's journal" and History's day headings (the mocks were cloned from frames without them, but removing them wasn't part of the critique); the step headers in the details flow keep the page-title size from Figma 3.2/3.3.

### M6.3 — One-tap entry and one entry page (built)
- **Source:** Figma journeys 2.1–2.11, 3.1–3.6 and 4.7–4.9 (first drawn as section 11.2, "One-tap entry"), approved by the product owner on 8 November 2026. It replaces the earlier M6.3 proposals (sections 11 and 11.1, kept as superseded drafts). The aim: logging is as quick as the notes app it replaces (open, tap, close).
- **One tap creates the entry:**
  - "Add an entry" saves straight away and opens the new entry's page. Today's entry records the current time. A past day selected in the week strip gets a date-only entry.
  - A rapid double tap creates one entry.
  - The page shows "Added to today" with Undo; Undo deletes the new entry and returns to the journal.
- **One entry page** replaces Entry details and Edit entry (and the old add-entry steps). The journal, a selected day and History all open it.
  - **Layout:** title ("Today's entry", "Wednesday's entry"), When (Change), the Context and Stool form cards when their settings are on, Note with counter, and "Delete this entry" for an entry that existed before.
  - **Saved/Save button:** it reads "Saved" (disabled, tick icon) until the date/time or note changes, then "Save" with "Unsaved changes" above it. Save persists and returns to the journal.
  - **Leaving:** close (×), back gesture or system back with unsaved changes asks "Discard changes?".
- **Details sheet:**
  - The Context and Stool form cards open one sheet with a page per enabled detail (Context first). It opens on the page of the card that was tapped.
  - A two-segment bar shows the position. Swipe moves between pages. The button reads Next, then Done on the last page; with one page, only Done.
  - Clear on each page.
  - Choices save as soon as they are picked, so closing the sheet any way keeps them.
  - The cards then summarise the choices ("Easy · After a meal, Coffee", "Type 4 · Smooth and soft").
- **Wording:**
  - "A little context" becomes "Context" (Settings switch, card and sheet page).
  - The tags question becomes "Anything going on?" with "Choose all that apply".
  - "How did it feel?" becomes a three-way segmented control.
  - The tags are in two rows: food and drink, then body and mind.
- **Rules changed:** CLAUDE.md and PRODUCT.md were updated on 8 November (one-tap creation, the entry page, the details sheet, the "Context" name).
- **Decided on 8 November:**
  - **Lock while editing:** unsaved date/time or note changes are discarded when the app locks. The entry itself is already saved.
  - **Undo lifetime:** Undo stays on the page until the user leaves it.
  - **Undo after editing:** Undo asks "Undo this entry?" and then deletes the entry (Figma 2.11).
  - **Failed one-tap save:** shown on the journal (2.10), with nothing saved.
- **Accept when:**
  - Unit and widget tests cover: one-tap creation (today timed, past day untimed), the double-tap guard, Undo, the Saved/Save state, the discard prompt, sheet paging (Next, Done, swipe, one-page case), that choices persist when the sheet is dismissed, Clear, and that hidden settings hide their cards.
  - Screen-reader labels cover the button state and the sheet position ("Page 1 of 2").
  - The 200% text check passes on the S20.
  - DESIGN.md and the design catalogue's build status are updated.

- **Built (8 November):**
  - **Code:**
    - `presentation/entry/`: `quick_add.dart` (one-tap add, double-tap guard, failure state), `entry_page.dart` and `entry_page_controller.dart` (one page; date, time and note unsaved until Save; details stored as chosen and written in order; Undo), `details_sheet.dart` (the two-page sheet) and `entry_time_sheet.dart` (moved, unchanged).
    - One `/entry` route above the tabs. `extra` is `(id, isNew)`, never a path.
    - `EntryRepository.updateDetails` writes only the details, in one transaction.
    - New `MorrowSegmented` widget for "How did it feel?". `SettingRow.navigation` gained a text action ("Change").
    - Removed: the old editor, step screens, Entry details and Edit entry, and their routes.
  - **Tests:** 306 pass.
    - The new controller tests cover quick add (today timed, past day untimed, double tap, failure and retry), Save, discarding, future times, details written in order and rolled back on failure, and Undo.
    - The widget tests cover the one-tap flow, Saved and Save, Undo with and without changes, the discard prompt, the failed add and failed Save, the four setting combinations, sheet paging (Next, Done, swipe, one page), dismissing the sheet keeps the choices, Clear, hidden values kept, and 100% and 200% text.
  - **Device check (S20, 8 November):**
    - `integration_test/journal_flow_test.dart` passes. It covers one-tap add, change, Undo and delete, through the real encrypted database in a temporary folder. The encryption self-check and startup device tests also pass.
    - Checked by hand at 100%:
      - the one-tap page and "Saved"
      - a note waking "Save" with the bar above the keyboard
      - Undo after a change asking first
      - "Context" in Settings
      - both detail cards
      - the sheet's Next, swipe and tap-outside dismiss, with choices kept
    - Checked at 200%: the entry page, the Context page and the Stool form page.
  - **Fixed during the device check:**
    - A toast from the journal covered the next entry page's Save bar. The entry page now clears it on open.
    - Clear showed when there was nothing to clear. It's now hidden, with its space kept.
    - The two tag rows were too far apart.
    - At 200% the segmented labels broke mid-word ("strainin/g"). The segments now stack as rows when a label doesn't fit.
    - At 200% the "Anything going on?" heading was squeezed by its hint. The hint now wraps below.
  - **Still to check:**
    - TalkBack on "Saved", the segments ("Easy, 1 of 3") and "Page 1 of 2"
    - iOS (M3's device check is still open)
  - **Differences from Figma:**
    - The disabled "Saved" button uses the theme's Disabled Surface rather than Sage Tint, like every other disabled button.
    - Both detail cards say "Not added" (Figma updated to match).

### M7 — Weekly trends (built)
- **Scope (5.1–5.7):** 4/12/26-week ranges with previous/next navigation, summary tiles, weekly bar chart (Flutter widgets or CustomPaint), stool form and symptom sections behind their settings, not-enough-data state, and no health advice.
- **Accept when:** golden-free widget tests check the figures against M2 fixtures, and the bars have semantic labels such as "Week of 2 Nov, 5 entries".
- **Built (8 November):**
  - **Code:**
    - `trends/presentation/trends_controller.dart`: the range and how many ranges back, and a view computed from the stored entries with `summariseWeeks`.
    - `trends_screen.dart`: range tabs, pager, three figure tiles, the weekly bar chart and the stool form card, all plain Flutter widgets with no charting package.
    - New colour token `chartBar` (#83917a) so bars meet 3:1.
  - **Tests:** 315 pass. The new widget tests check:
    - the Figma figures for 4, 12 and 26 weeks
    - bar labels ("Week of 2 Nov, 5 entries, in progress")
    - the pager (earlier, later, never the future, not before the first entry)
    - the stool card only with its setting on
    - no advice wording
    - 100% and 200% text
  - **Device:** `integration_test/trends_test.dart` passes on the S20 with the synthetic Figma journal in a temporary database. `--dart-define=MORROW_HOLD=true` holds each screen for a look. 4 and 26 weeks and the stool form card were checked visually.
  - **Differences from Figma:**
    - The bars for completed weeks are a darker sage, for contrast.
    - With 26 weeks the middle axis label is the 14th week (10 Aug), not 3 Aug.
    - "Optional · Bristol scale" is kept on the stool card (decision 8).
  - **Still to check:** TalkBack reading the bars and tabs; 200% on the device (covered by widget tests only).

### M7.5 — On-device diagnostics log (built, designs in Figma 10.1–10.6)
- **Why:** app lock, reminders, key storage and saves fail in ways that are hard to see on a phone. A local log of what the app did lets the user send evidence without the app ever collecting anything itself.
- **What is logged:**
  - Fixed event codes from an allowlist (for example `app.open`, `journal.unlocked`, `entry.saved`, `entry.save_failed.storage`, `reminder.scheduled`, `key.read_failed`), each with the local time.
  - Never: entries, notes, details, entry dates or times, ids, keys, SQL, file paths, or raw exception text. A log line can only be built from a code, so free text can't get in.
- **Storage:**
  - A rotating file in app-private storage: the last 30 days, up to 500 events.
  - Excluded from OS backup, like the journal.
  - Not in the user's own backups.
  - Erased by "Delete all data" and by turning the log off.
  - Logging must never block or fail a user action.
- **Screens (Figma 10):**
  - **10.1:** Settings > Support > Diagnostics.
  - **10.2:** what is and isn't recorded, the "Keep a diagnostic log" switch (on by default) and recent events.
  - **10.3 to 10.5:** "Save a copy" opens the phone's save sheet and leads to "Log saved" (10.5). "Share by email" asks first ("Share the log?", 10.3), then opens the phone's share sheet (10.4), and the email app sends it. morrow has no network access and never sends email itself.
  - **10.6:** the log off, with buttons disabled.
- **To confirm before building:**
  - The share and save package (an OS share sheet plugin such as `share_plus`, also needed by M11 backups), checked for advisories, licence and native permissions.
  - The on-by-default choice.
  - The 30-day and 500-event limits.
  - Whether the plain-text file is acceptable, given that it holds no personal content.
- **Accept when:**
  - Unit tests prove only allowlisted codes can be written, rotation works, and turning the log off or deleting all data erases it.
  - A test scans log output from failure paths for entry content (none).
  - On the S20: saving through the save sheet, and sharing to an email app with the file attached.

- **Decided on 8 November:** `share_plus` 13.3.1 and `file_picker` 13.3.2, the log on by default, and 30 days or up to 500 events.
- **Built (8 November):**
  - **Code:**
    - `core/diagnostics/diagnostic_log.dart`: the `DiagnosticEvent` allowlist, and `FileDiagnosticLog`, which stores `time code` lines in `Application Support/diagnostics/events.log`. Writes are queued and never throw. The log prunes to 30 days and 500 events. An `off` marker file records that it was turned off, and turning it off deletes the log.
    - `core/platform/file_export.dart`: the save sheet (file_picker) and share sheet (share_plus) behind a `FileExport` interface. The temporary copy made for sharing is deleted when the sheet closes.
    - `settings/presentation/diagnostics_screen.dart`: screens 10.2 to 10.6, plus Settings > Support > Diagnostics.
    - Events are recorded at startup (opened, created, each blocked reason, failed), on erase, and when adding, saving, saving a detail, deleting or undoing an entry fails.
  - **Not logged by design:** successful journal actions (adding, changing or deleting an entry). Their times would reveal when entries were made. The Figma example rows "Entry added" and "Entry page opened" therefore don't occur.
  - **Native:** neither plugin adds an Android permission. file_picker declares its file intents. share_plus adds a private FileProvider and copies shared files into its own cache folder. That copy is acceptable here because the log holds no personal content, but M11 backups must clear it. file_picker needs iOS 14; the app targets iOS 15.
  - **Layout:** at large text sizes the two buttons scroll with the page instead of being pinned.
  - **Tests:** 331 pass. They cover:
    - the log file: format, order, the 500-event cap, the 30-day cut-off, turning it off and on, ignoring unknown lines, and never throwing
    - the export format
    - failure events recorded with no note or error text
    - no events for successful actions
    - the screen: events, save leading to "Log saved", a cancelled save, share asking first, a dismissed share, turning the log off, and 100% and 200% text
  - **Device check (S20, 8 November):**
    - The page records "App started" and "Journal opened".
    - "Save a copy" opens the phone's save sheet with `morrow-diagnostics-2026-11-08.txt` filled in; cancelling returns quietly.
    - "Share by email" asks first, then opens the share sheet with the file attached; it was closed without sending.
    - Our temporary copy is deleted afterwards. share_plus keeps its own copy in `cache/share_plus`; it's left so an email app can still read the attachment, and it is replaced on the next share.
    - The journal, trends and startup device tests pass.
    - Fixed during the check: at 200%, the event names broke mid-word, so the time now sits above the event at large text sizes.
    - Not done: a completed save or send, which would put a file in your folders or an email draft.
  - **Still to do:**
    - **M10:** add `diagnostics/` to the backup exclusions and clear it in "Delete all data".
    - **M11:** clear share_plus's cache copy.

### M8 — App lock (built)
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
- **Decided on 8 November:**
  - The native changes as proposed.
  - A blank recent-apps preview with screenshots still allowed (no FLAG_SECURE).
  - Relock immediately on going to the background.
- **Built (8 November):**
  - **Code:**
    - `core/security/device_auth.dart`: local_auth 3.0.2 with device-credential fallback and `persistAcrossBackgrounding`. Errors map to cancelled, failed, lockedOut, notAvailable or error.
    - `core/security/lock_settings.dart`: the setting in secure storage, outside the journal database, with the same platform options as the key.
    - `core/platform/privacy_shield.dart` and `MainActivity`: the `morrow/privacy` channel calls `setRecentsScreenshotEnabled(false)` on Android 13+ while app lock is on.
    - `app/lock/lock_controller.dart`: starting up, locked, unlocking, unlocked and error states, and a session token that discards stale results.
      - It fails closed when the setting can't be read.
      - It relocks on `hidden` or `paused`, never on `inactive`, and asks again on return. The prompt's own lifecycle changes are ignored, and a cancelled prompt is never reopened by itself.
      - Turning the lock on or off needs authentication first. A cancelled or failed confirmation changes nothing.
    - `app/app.dart`: an `AppLifecycleListener` drives the controller. While the lock is on, a plain privacy cover is shown whenever the app isn't resumed.
    - The locked screen (7.4, 7.5), with messages for lockout, no screen lock, a prompt failure and an unreadable setting.
    - Settings > Privacy > App lock, and the App lock screen (7.1, 7.3). The system prompt serves as 7.2 and 7.6.
    - Diagnostics events for turning the lock on and off, failed unlocks, lockout, unavailable unlock and an unreadable setting.
  - **Native:**
    - `FlutterFragmentActivity`.
    - `USE_BIOMETRIC`, declared explicitly. The merged manifest also gains `USE_FINGERPRINT` from androidx.biometric, for Android 9 and older.
    - An AppCompat `LaunchTheme`, which local_auth needs on Android 8 and older.
    - `minSdk = 24`, pinned.
    - iOS `NSFaceIDUsageDescription`: "morrow uses Face ID to unlock the app."
    - INTERNET is in the debug and profile manifests only (Flutter tooling).
  - **Draft policy:** locking removes the unlocked scope, so the database closes and unsaved date, time or note changes on the entry page are discarded. The entry itself is already saved. The app reopens on the journal home.
  - **Tests:** 356 pass.
    - Controller: every transition, every failure outcome keeping the lock on, backgrounding versus inactive, the prompt's own pauses, the stale result, and turning the lock on and off (cancelled, failed save, its own prompt).
    - App: nothing sensitive while locked, Couldn't unlock with Try again, lockout and no screen lock, the cover on inactive, relocking on hidden and paused with the database closed, no cover with the lock off, Settings > App lock, and 100% and 200% text.
    - The integration tests now use a fake lock setting, so they never read or change the phone's real one.
  - **Device check (S20, 8 November):**
    - Turning the lock on with the fingerprint or PIN prompt works.
    - The recent-apps card is blank.
    - Returning asks again.
    - Cancelling shows Couldn't unlock without reopening the prompt, and Try again then unlock works.
    - The journal, trends, startup and encryption device tests pass.
  - **Not checked:**
    - Lockout after repeated failures.
    - PIN fallback, as distinct from the fingerprint.
    - A cold start with the lock on.
    - TalkBack.
    - iOS: Face ID, and the app-switcher cover, which isn't guaranteed.
    - The first-launch screens (1.1–1.3), now planned as M11.1.
  - **Security note:** the lock is an app gate. A successful local_auth result does not unlock the database key cryptographically; binding the key to authentication remains a separate enhancement.

### M9 — Weekly reminder (built)
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
- **Decided on 8 November:**
  - flutter_local_notifications 22.3.3 with the current tooling (AGP 9.1.0, compileSdk 36).
  - The native changes as proposed, including "Open phone settings".
- **Built (8 November):**
  - **Code:**
    - `core/notifications/reminder_scheduler.dart`: one adapter for permission, `zonedSchedule` and cancel, with `inexactAllowWhileIdle` and `DateTimeComponents.dayOfWeekAndTime`.
      - The zone is read by IANA name through flutter_timezone every time it schedules.
      - `nextWeekly` keeps the wall-clock time across a clock change.
      - The wording is generic ("Weekly check-in" / "Ready to add an entry?") and there's no payload.
    - `features/reminders/`:
      - The repository holds the existing `reminder` row (no schema change).
      - `ReminderController` keeps the intent apart from the observed permission and schedule. It reconciles when the journal opens, on resume and after every change.
      - Operations run one at a time, the one stable id is always replaced, and rescheduling is skipped when nothing changed.
      - A refusal saves the reminder anyway (6.4).
    - The Weekly reminder screen (6.1–6.4) and Settings > Reminders.
    - Diagnostics events: scheduled, turned off, scheduling failed, notifications not allowed.
  - **Native:**
    - `RECEIVE_BOOT_COMPLETED`, plus the plugin's `ScheduledNotificationReceiver` and boot receiver (boot, package replaced, quick boot).
    - Core library desugaring (desugar_jdk_libs 2.1.4) and multidex.
    - The `openNotificationSettings` method on the `morrow/privacy` channel.
    - iOS: the `UNUserNotificationCenter` delegate.
    - The merged manifest adds `POST_NOTIFICATIONS` and `VIBRATE` (from the plugin) and `RECEIVE_BOOT_COMPLETED`. There are no exact-alarm or battery permissions.
    - On iOS, "Open phone settings" is replaced by text (no native channel yet).
    - The `timezone` package pulls in `http` as a dependency. The app never imports it.
  - **Found on the device and fixed:**
    - The permission prompt backgrounds the app, and the reconcile on resume overwrote the result, leaving "Turning on…". This is fixed by serialising operations and has a regression test.
    - The day picker laid out as a column. It's now one row of seven circles, with a test.
    - Text actions in setting rows ("6:00 pm") overflowed at 200%. They now wrap.
    - The device tests started the real app with an empty journal, which cancelled the real reminder and wrote test events into the real diagnostics log. All device tests now use fake schedulers, lock settings and logs.
  - **Tests:** 378 pass. Controller tests cover:
    - off by default, switching on, refusal, a resume during the prompt, and replacing the reminder
    - switching off keeping the day and time
    - an unchanged reconcile, permission revoked, a zone change, a schedule cleared by the OS, a scheduling failure, and a restart
    - `nextWeekly`, including the October clock change

    Screen tests cover 6.1, 6.3 (one-row days), 6.4 (Open phone settings), allowing later and picking it up on return, switching off, and 100% and 200% text.
  - **Device check (S20, Android 13, 8 November):**
    - The prompt appears only when switching on, and "Don't allow" shows 6.4.
    - Open phone settings goes to morrow's notification page, and allowing there is picked up on return (6.3).
    - `dumpsys alarm` shows one morrow alarm, Sunday 15 November at 18:00, with a one-hour inexact window. Changing the day replaces it rather than adding another.
    - An app update keeps it.
    - A Force Stop clears it and reopening restores it.
    - The journal, startup, trends and encryption device tests pass.
  - **Not checked:**
    - Actual delivery at the time.
    - Reboot.
    - Battery saver.
    - Tapping the notification (it opens the app through the lock gate, with no payload).
    - iOS.
    - TalkBack.
  - **Behaviour while closed:** the OS keeps the reminder at the wall-clock time in the zone it was scheduled in. After travelling, it moves to the new zone the next time morrow is opened.

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

### M11.1 — Welcome and first launch (Figma 1.1–1.4)
- **Why:** no milestone covered the first-launch screens. Today a fresh install goes straight to the empty journal.
- **Scope:**
  - **1.1 Welcome**, shown once on a fresh install, before the journal: "A little daily clarity.", three promises (stays on this phone, private by default, keep your own backup), and Get started, Set up app lock and Restore from a backup.
  - **1.2 and 1.3:** "Set up app lock" turns the lock on with the phone's own prompt (M8), then confirms "App lock is on".
  - **Restore:** "Restore from a backup" goes to the M11 restore flow, then into the journal.
  - **1.4:** "Get started" leads to the empty journal.
  - **Seen flag:** whether Welcome has been seen is security bootstrap metadata, so it lives in secure storage, not in the database. A restored or reinstalled phone that already has a journal never shows Welcome again.
  - **Wording:** neutral throughout ("entry", "journal"). Nothing reveals what is tracked.
- **Depends on:** M8 (app lock) and M11 (restore).
- **Accept when:**
  - Widget tests show Welcome only on a genuine first install, never again after Get started, and never when a journal exists.
  - Set up app lock handles success, cancel and no screen lock.
  - Restore from a backup returns to Welcome on cancel.
  - 200% text works.
  - Manual device check: a fresh install on the S20.

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
