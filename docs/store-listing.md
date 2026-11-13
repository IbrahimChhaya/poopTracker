# Store listing (approved 13 November 2026)

**History:**
- **9 November:** the owner approved a neutral listing.
- **13 November:** the owner decided the store should say plainly what morrow is for, so people can find it. The listing text and the screenshots now say "bowel movements". The owner approved this text and the Figma section 14 screenshots.

**Still neutral:**
- the app name, "morrow"
- the launcher label
- notifications
- onboarding
- everything inside the app outside the entry page and its details sheet

**Wording:** plain, not crude or clinical ("bowel movements", "Bristol stool type"). There are no medical claims, and morrow is described as a personal log, not a diagnostic tool. Screenshots use synthetic data only, with the optional details switched **on**.

**Developer name:** Ibrahim, the owner's own name, on both stores (see "Developer name" below for how Apple shows it).

## Google Play

| Field | Limit | Draft |
|---|---|---|
| App name | 30 | **morrow: bowel movement log** (26) |
| Short description | 80 | **A private log for your bowel movements. Encrypted, offline, no account.** (73) |
| Category | | Health & Fitness |
| Tags | | Health & fitness, Journal, Tracker |
| Contains ads | | No |
| In-app purchases | | No |
| Developer name | | Ibrahim |

**Full description** (4,000 limit):

> morrow is a simple, private log for your bowel movements.
>
> **One tap to log.** Tap "Add an entry" and it's saved straight away, with today's date and time. Add a note or change the time if you like, or don't. Only the date is ever needed.
>
> **Add detail if you want it.** Switch on Stool form to record the Bristol stool type (1 to 7), or Context to note how easy it was and what was going on (after a meal, coffee, travel and more). Both stay off until you turn them on, and turning them off never deletes anything.
>
> **Look back by the week.** See this week at a glance, browse and search earlier entries, and view simple weekly counts over 4, 12 or 26 weeks, with a stool type summary if you record it. No scores, streaks or judgement.
>
> **Discreet on your phone.** The app is called morrow, its icon is a small sprout, and its weekly reminder just says "Weekly check-in". Nothing on your home screen or lock screen says what it's for.
>
> **Private by design.**
> • Your log stays on this phone, encrypted.
> • No account, no sign-in, no cloud, no ads, no analytics.
> • morrow works entirely offline.
> • Optional app lock with your fingerprint, face or phone passcode.
>
> **Your data, your backup.** Export an encrypted backup protected by a passphrase you choose, and save it wherever you like. Restore it on a new phone; entries already there are kept. Your passphrase can't be recovered, so keep it safe.
>
> **Delete everything, any time.** One clear step removes every entry, setting and reminder from the phone.
>
> morrow is a personal log, not a medical device. It doesn't diagnose, interpret or give health advice. If you're worried about your health, speak to a doctor.

### Play Console declarations
- **Data safety:**
  - **Data collected:** none. Data that stays on the device isn't "collected" in Play's terms.
  - **Data shared:** none.
  - **Encrypted in transit:** not applicable.
  - **Deletion:** in the app (Settings > Data & privacy > Delete all data).
- **Health apps declaration** (Policy > App content): every app must complete it.
  - Declare the health feature: a personal log of bowel movements and stool type, kept on the device. Pick the closest listed category when filling it in.
  - Not a medical device, and no Health Connect access.
  - **This declaration makes a privacy-policy URL necessary.**
- **Privacy policy URL:** required (see below).
- **Permissions to justify:**
  - `USE_BIOMETRIC`: optional app lock.
  - `POST_NOTIFICATIONS`: optional weekly reminder, asked for only when it's turned on.
  - `RECEIVE_BOOT_COMPLETED`: keeps the reminder after a restart.
  - No internet permission.

### Screenshots and graphics
The designs are in Figma section 14 (approved 13 November).
- **Play screenshots:** 1080 × 1920. Play allows a 2:1 ratio at most.
- **App Store screenshots:** 1290 × 2796.

Before upload, swap each screen for a capture of the release build with the same synthetic entries.
1. **Journal with stool types.** Caption: "Log your bowel movements privately".
2. **Entry page with details added and "Saved".** Caption: "One tap to log it. Add detail if you like."
3. **Stool form sheet (Bristol scale).** Caption: "Bristol stool type, ease and context".
4. **Trends, 12 weeks, with the stool form summary.** Caption: "Simple weekly counts, no scores".
5. **Lock screen with the "Weekly check-in" reminder.** Caption: "Discreet: your phone just says morrow".
6. **Welcome tour, Private by design.** Caption: "Encrypted on your phone. No account."
7. **Export a backup.** Caption: "Your own encrypted backup".

**Feature graphic (Play, 1024 × 500):** sage background, the sprout and "morrow", "Log your bowel movements privately", "On your phone. Encrypted. No account.", and the journal screen.

**Icons:** the Play icon is `docs/store/icon-512.png`. The App Store icon is the 1024 px AppIcon in the iOS project.

## App Store (iOS)

| Field | Limit | Draft |
|---|---|---|
| Name | 30 | **morrow** |
| Subtitle | 30 | **Private bowel movement log** (27) |
| Promotional text | 170 | **Log bowel movements in one tap, with Bristol stool type if you like. Encrypted on your phone, offline, no account. Discreet: your phone just says morrow.** (153) |
| Keywords | 100 | **poop,stool,bristol,bowel,toilet,gut,tracker,diary,private,log,digestion,offline** (82; hidden from users; avoids repeating the name and subtitle) |
| Category | | Health & Fitness (secondary: Lifestyle) |
| Age rating | | 4+ (the questionnaire's medical-information question: none; it's a personal log) |
| Price | | Free |
| Support URL | | required (see below) |
| Privacy policy URL | | required (see below) |

**Description:** as the Play full description, with "phone" kept and the fingerprint wording changed to "Face ID or passcode".

### App Privacy ("nutrition label")
- **Data Not Collected.**
- **Tracking:** no.

## URLs (both stores need them)
- **App Store:** a privacy-policy URL is required for every app, and App Store Connect also asks for a support URL.
- **Google Play:** a privacy-policy URL is required for apps that declare health features.
- **Drafts:** `docs/privacy-policy.md` and `docs/support.md`.
- **Hosting:** GitHub Pages, from `docs/` on `main` (the repository was made public on 13 November).
  - **Privacy policy URL:** https://ibrahimchhaya.github.io/poopTracker/privacy-policy
  - **Support URL:** https://ibrahimchhaya.github.io/poopTracker/support
- **Contact:** GitHub Issues (https://github.com/IbrahimChhaya/poopTracker/issues). No email is published; the pages warn that issues are public.

## Developer name
- **Google Play:** shows the developer name you choose: **Ibrahim**.
- **App Store:**
  - shows the *seller*.
  - On an individual Apple Developer account (decided 13 November), the seller is the account holder's full legal name as enrolled, set by Apple.
  - It can't be shortened to "Ibrahim".
