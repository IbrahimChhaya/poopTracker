# morrow release checklist (M12)

Started 9 November 2026 on branch `m12-hardening`. Nothing here is called production-ready until every item is ticked with evidence on a real Android phone and a real iPhone.

Key: ✅ done with evidence · ⏳ to do · 🔒 needs the owner (a decision, an account or hardware)

## 1. Automated checks (done 9 November)

| Check | Result |
|---|---|
| `dart format`, `flutter analyze`, `flutter test` | ✅ Clean; 476 tests (including the accessibility guideline tests below). |
| Accessibility guidelines (`test/a11y/guidelines_test.dart`) | ✅ Journal, entry page, details sheet, History, Trends, Settings, Weekly reminder, App lock, Data & privacy, welcome and all four tour pages meet Flutter's Android 48 px and iOS 44 pt tap-target, labelled-tap-target and text-contrast guidelines. These guidelines don't prove screen-reader behaviour. |
| Release Android manifest (`flutter build apk --release`) | ✅ Permissions: `USE_BIOMETRIC` and `USE_FINGERPRINT` (local_auth); `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS` and `VIBRATE` (reminder); and the AndroidX dynamic-receiver permission. **No `INTERNET`.** `allowBackup="false"`, with backup and data-extraction rules. Exported components: `MainActivity` (launcher) and AndroidX `ProfileInstallReceiver` (guarded by `android.permission.DUMP`); everything else is `exported="false"`. |
| Network use | ✅ The app's code makes no network calls: no HTTP or socket APIs, no network images, no fonts or assets loaded at run time. `http` comes in only through `timezone`, whose time-zone data is bundled; the app never calls it. Even if it did, the release Android build has no INTERNET permission. `web_socket` is a development-only dependency. |
| Licences (112 packages in the resolved tree) | ✅ All permissive: BSD-2/BSD-3, MIT or Apache-2.0. The one exception is `dbus` (MPL-2.0), used only by the Linux desktop plugins, so it isn't in the Android or iOS builds. Flutter SDK packages are BSD-3. The native SQLite3MultipleCiphers bundled through `sqlite3` is MIT. |
| Security advisories (GitHub advisory database, Pub ecosystem) | ✅ No advisory affects a shipped version. The only package match, `http` GHSA-4rgh-jx4f-qfcq, affects versions before 0.13.3; the app ships 1.6.0. `flutter pub outdated` shows newer majors for 12 packages. That's an update question, not a security finding; it's deferred by the existing "don't chase every major" rule (for example flutter_local_notifications 23 needs AGP 9.1.1). |

## 2. Decisions and setup for the owner 🔒

1. **Android application ID.** It's `com.chhaya.poop_tracker`. That appears in the Play Store URL and in Android's app info, so it reveals what the app tracks, and it **can't be changed after the first release**. Proposed: `com.chhaya.morrow`. The iOS bundle ID `com.chhaya.poopTracker` has the same issue (proposed: `com.chhaya.morrow`). Changing either now is cheap. On Android, a phone that already has the old ID installs the new build as a separate app, with a fresh journal.
2. **Release signing.** The release build is still signed with the debug key. You create an upload keystore (Play App Signing) and keep it **outside the repository**; the build reads it from `key.properties`, which is git-ignored. Signing material must never be committed.
3. **Launcher icon.** It's still the Flutter default on both platforms. It needs a neutral mark, for example the sprout on cream, with no subject imagery. I can draw options in Figma; you choose.
4. **Store listing text.** Name, short and full description, and screenshots, in neutral wording ("journal", "entry", "check-in"). I can draft it for your approval. Screenshots use synthetic data only.
5. **iOS export compliance.** `ITSAppUsesNonExemptEncryption` isn't set. morrow uses encryption only to protect the user's own data on the device (SQLite3MultipleCiphers, plus AES-GCM for backups), which normally falls under the "exempt" categories. That's your call, though, and possibly a quick check with Apple's guidance; then the key is set in `Info.plist`.
6. **iOS privacy manifest.** `PrivacyInfo.xcprivacy` is missing. It declares no tracking, no data collected, and any required-reason APIs the app itself uses. Adding it needs Xcode on a Mac, because the file must be added to the project.
7. **Orientation.** Both `Info.plist` and Android allow landscape, but it was never designed or tested. Proposed: portrait only on phones for v1.
8. **Version.** `1.0.0+1` in `pubspec.yaml`. Confirm before the first upload.

## 3. Device checklist

### Android (Galaxy S20, Android 13)

| Area | Status |
|---|---|
| Encrypted database on the native build, key bootstrap, wrong or missing key blocked | ✅ (M3, re-run as device tests on 9 Nov) |
| Journal add, change, undo, delete; autosave across Home and Force Stop | ✅ (9 Nov) |
| Trends, Settings, Data & privacy, Delete all data (with the real file listing) | ✅ (M10, 9 Nov) |
| Backup export and restore with the real save sheet and file picker (Downloads) | ✅ (M11) |
| Welcome and tour on a new journal (device test, temporary journal) | ✅ (9 Nov) |
| OS backup exclusion (`bmgr` refuses) | ✅ (M10) |
| A real fresh install (deletes the phone's journal) | ⏳ Run once on a phone that holds nothing to keep |
| Reminder delivered at the chosen time; after a reboot; with battery saver on; tapping it opens through the lock gate | ⏳ 🔒 |
| App lock with fingerprint: unlock, cancel, lockout, the 1-minute system-sheet allowance, relock on backgrounding, app-switcher cover | ⏳ 🔒 |
| Delete all data with app lock on (re-authentication) | ⏳ 🔒 |
| TalkBack through every screen (passphrase fields, Trends summary, switches, tour pages) | ⏳ 🔒 |
| Google Drive export and restore | ⏳ 🔒 (needs a signed-in account) |
| Device-to-device transfer leaves morrow out | ⏳ 🔒 (needs a second phone) |
| Release build on the phone (not just debug) | ⏳ |

### iOS (nothing built yet)

⏳ 🔒 Needs a Mac with Xcode and an iPhone:
- Build and run.
- Encrypted database and Keychain key.
- Face ID unlock and the passcode fallback.
- App-switcher cover.
- Backup exclusion (`isExcludedFromBackup`).
- Notification permission and delivery.
- Document picker and save sheet (Files, iCloud Drive).
- VoiceOver.
- Large text.
- 24-hour clock.

## 4. Open product and code items

- **Quick "earlier today" time shortcuts** for logging later from memory. Needs a Figma proposal first.
- **Dark mode** is planned after v1; every colour is already a theme token.
- **Figma visual checks:** Figma screenshot export times out, and the REST token has expired. A new personal access token in the Figma MCP config restores the fallback.
