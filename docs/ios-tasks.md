# iOS tasks (for when a Mac is available)

Nothing has been built for iOS yet. The code is cross-platform and the iOS native pieces are written, but none of it has been compiled. Work through these in order; each step lists what proves it's done. Use synthetic data only.

## 0. Set up the Mac
1. Install Xcode (the version the current stable Flutter supports), its command-line tools and CocoaPods. Run `flutter doctor` until the iOS toolchain section is green.
2. Clone the repository, then run `flutter pub get` and `cd ios && pod install`.
3. Sign in to Xcode with the Apple Developer account. In `ios/Runner.xcworkspace`, select the team for the Runner target.
   - Bundle ID: `com.chhaya.morrow` (changed 9 November; the tests target is `com.chhaya.morrow.RunnerTests`).
   - **Done when:** `flutter build ios --debug` succeeds.

## 1. First build and run
1. Run on a real iPhone: `flutter run -d <iphone>`.
2. Fix any compile errors in the native code, which has never been compiled. The places most likely to need attention:
   - **`ios/Runner/AppDelegate.swift`:**
     - the `morrow/privacy` method channel registered through `engineBridge.pluginRegistry.registrar(forPlugin: "MorrowPrivacy")`
     - the `excludeFromBackup` method (`URLResourceValues.isExcludedFromBackup`)
     - the `UNUserNotificationCenter` delegate set-up
   - **`ios/Runner/SceneDelegate.swift`** (scene-based life cycle).
   - **Plugin minimum versions:** the app targets iOS 15; file_picker needs iOS 14.
   - **Done when:** the app opens to the welcome on a new install.

## 2. Project files that need Xcode
1. **Privacy manifest.** Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target (File > New > App Privacy):
   - `NSPrivacyTracking` = false
   - no tracking domains
   - `NSPrivacyCollectedDataTypes` = empty (nothing is collected)
   - required-reason APIs the app's own code uses. Check the Xcode privacy report after archiving. File timestamps are likely, from path_provider and file handling, with the reason `C617.1`.

   Plugins ship their own manifests; check they're included in the archive's privacy report.
2. **Export compliance.** `ITSAppUsesNonExemptEncryption` = false is set in `Info.plist` (decided 9 November). Encryption only protects the user's own data on the device: the encrypted SQLite journal and AES-GCM backups.
   - **Done when:** App Store Connect doesn't ask the encryption question on upload.
3. **App icon.** Already generated: option A, the sage sprout on cream. `tool/generate_launcher_icons.py` writes every file in `Assets.xcassets/AppIcon.appiconset`, all opaque, including the 1024×1024.
   - **Done when:** Xcode shows no AppIcon warnings and the archive validates. If Xcode asks for the single-size 1024 format, regenerate or let Xcode convert.
4. **Launch screen.** `LaunchScreen.storyboard` should be the cream background with the sprout, matching the Android splash.

## 3. Security and privacy checks on the iPhone
| Check | Done when |
|---|---|
| Encrypted database on the real build | The Settings > Developer > Encryption self-check passes in a debug build. A copied `journal.db` doesn't open without the key (`integration_test/encryption_self_check_test.dart` passes on the iPhone). |
| Keychain key | The key is created on first start with `first_unlock_this_device` and isn't synchronised (check `SecureStorageKeyStore.iosOptions`). Deleting the app and reinstalling gives the blocked or fresh-journal behaviour the plan describes, never silent data replacement. |
| Backup exclusion | After the first start, the app-support folder has `isExcludedFromBackup` set (inspect from Xcode's Devices window or with a debug print). An encrypted iCloud or computer backup restored to a phone doesn't bring back a readable journal. |
| App lock with Face ID | `NSFaceIDUsageDescription` shows in the prompt. Covers unlock, cancel (plain locked screen, no error), a failed match, the passcode fallback, lockout and no passcode set. Relocks after real backgrounding but not during the prompt. Also covers the 1-minute allowance for morrow's own sheets. |
| App-switcher cover | The sprout cover shows in the app switcher while app lock is on. |
| Delete all data | Works with and without app lock. Afterwards the app's Documents and Library folders hold no journal, diagnostics or cache files, and the Keychain items are gone. |

## 4. Feature checks on the iPhone
| Area | Done when |
|---|---|
| Welcome and tour | Shown on a new install only. The real switches and the App lock switch work, the back arrow appears from page 2, edge-swipe back works, and Skip and Start land on the journal with the hint. |
| Journal | One-tap add, Undo, autosave (type, then swipe home, kill and reopen), delete, the week strip, History search and the date filter. |
| Time picker | Follows the phone's 24-hour setting, and all labels agree. |
| Weekly reminder | Permission asked only when turned on. Refusing shows 6.4 with the text fallback (there's no "Open phone settings" on iOS yet). The notification arrives at the time with "Weekly check-in / Ready to add an entry?". Tapping it opens through the lock gate. Changing the day replaces it. |
| Backup and restore | Export through the Files sheet (On My iPhone and iCloud Drive). Restore with the document picker, covering a wrong passphrase, a newer file and duplicates skipped. Nothing is left behind in the app's tmp folder afterwards. |
| Diagnostics | Save and share the log through the share sheet. |
| Trends | 4, 12 and 26 weeks; Stool form only when the setting is on. |

## 5. Accessibility on the iPhone
1. **VoiceOver** through every screen. Check:
   - the passphrase fields are read with their labels
   - Trends reads one summary for 12 and 26 weeks
   - the tour reads "Page n of 4", the previews are silent, and the switches announce their state
   - toasts and status pages are announced.
2. **Larger Text** at the largest accessibility size. Pages scroll, nothing is clipped, and the tour's Next stays pinned.
3. **Bold Text, Increase Contrast and Reduce Motion:** nothing breaks.

## 6. Release
1. Version `1.0.0` (build `1`), confirmed 9 November.
2. Archive in Xcode, then validate and upload to App Store Connect.
3. TestFlight install from scratch on the iPhone, repeating section 4's smoke test.
4. Fill in the App Store listing from `docs/store-listing.md`:
   - privacy "nutrition label": **Data Not Collected**
   - age rating
   - support URL
5. Record the results in `docs/release-checklist.md`.

## 7. Known iOS gaps to decide on
- **"Open phone settings"** on the notifications-off screen (6.4) is Android-only. iOS shows text instead. An iOS version would open `UIApplication.openSettingsURLString`, which needs a small native addition.
- **iPad.** The app is designed for phones. Either support iPad orientation and multitasking properly, or exclude iPad from the first release (`TARGETED_DEVICE_FAMILY = 1`). Recommended: iPhone only for v1.
