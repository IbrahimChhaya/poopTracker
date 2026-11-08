# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

One Flutter app for iOS and Android with a single shared morrow design (themed Material widgets, no per-OS look). Design work respects both platforms' conventions: back gestures, system sheets and pickers, system font scaling and screen readers.

## Users

Anyone who wants a private, low-effort personal record of their own bowel habits, for everyday awareness. They log in a moment, usually shortly after the event and sometimes later from memory, on their own phone. They aren't approaching it as patients. The app must never feel clinical, judgemental or embarrassing.

## Product Purpose

morrow is a simple, discreet personal journal. People record an entry with a date and, optionally, a time, a plain-text note and a few optional details, then look back over a weekly journal, a searchable history and simple weekly trends. An optional weekly reminder and an optional app lock support it.

Success means logging takes seconds, nothing is required beyond the date, and coming back to the app is calm and private.

It is a personal journal, not a diagnostic or treatment tool.

## Positioning

**Calm and low-effort.** The gentlest possible logging:
- one tap to add an entry
- everything except the date is optional and skippable
- the rhythm is weekly, not daily
- there are no scores, judgements or "insights"

Privacy and discretion are a given rather than the headline: the journal is encrypted on the device, there's no account or cloud, and the wording is neutral.

## Operating Context

- **Getting started:** opening the app goes straight to the weekly journal, with no account or sign-in.
- **Logging an entry:**
  - The user taps "Add an entry". The date defaults to today and the time to now.
  - Logging for a past day leaves the time out unless the user adds one.
  - Optional steps (stool form, "a little context") appear only when switched on in Settings.
  - A note is always available.
- **Looking back:**
  - The home screen shows this week's journal, with swipeable earlier weeks and a selectable day.
  - History shows entries grouped by day, with note search and a date filter.
  - Each entry has its own detail screen, where it can be edited or deleted.
  - Trends shows weekly counts over 4, 12 or 26 weeks.
- **Optional extras:** one weekly reminder with generic wording ("Weekly check-in"), and an optional app lock using the phone's own biometrics or passcode.
- **Backups:** the user can export an encrypted backup through the phone's own save sheet and restore from a file through its file picker. The backup is their only recovery route.

## Capabilities and Constraints

- **Local only.**
  - No accounts, backend, sync, analytics, advertising, remote crash reporting, runtime AI or network-loaded assets.
  - The journal database is always encrypted.
- **Discreet everywhere outside the entry flow.** The app name, launcher label, notifications, onboarding and store text say "morrow" and use neutral words ("entry", "log", "check-in"). Bowel-related wording and imagery appear only inside the entry flow and entry detail, and only when the user has switched those details on.
- **What an entry holds:**
  - **Required:** the entry and its date.
  - **Optional:** the time of day, a plain-text note (up to 500 characters), Bristol stool form (1–7), ease ("How did it feel?"), and circumstance tags (After a meal, Coffee, Stress, Low fluids, Medication, On my period, Feeling sick).
  - **Not recorded:** symptoms.
- **Optional detail settings.** Two Settings switches, "Stool form" and "A little context", are both off by default. A hidden detail is hidden everywhere, but its stored values are kept.
- **Weekly by design.**
  - Weeks run Monday to Sunday.
  - The home screen is "This week's journal"; earlier weeks can be viewed, future days can't.
  - Trends are descriptive weekly counts only: no modelling, forecasting, scoring or health advice.
- **Language:** British English.
- **No dark mode yet** (planned after v1). All colours live in theme tokens.
- **Undecided:**
  - the M6.2 refinements to the "A little context" step (for example renaming "Anything to note?")
  - the store listing text
  - the launcher icon

## Brand Commitments

- **Name:** morrow (always lower case), with a small sprout mark.
- **Voice:** calm, plain and kind. Neutral wording ("entry", "journal", "check-in"). No medical interpretation.
- **Source of truth for screens:** the Figma file `poopTracker`, which keeps the existing morrow theme (green and cream).

## Evidence on Hand

- **Screens:** the Figma file (66 frames in journeys 1–9), catalogued in `docs/design-catalogue.md`.
- **Data:** synthetic fixtures only (for example the Trends fixture in `test/fixtures/`).
- **What doesn't exist yet:** no users, testimonials, reviews, press, usage data or clinical claims. None of these may be invented.

## Product Principles

1. **The date is the only must.** Every other field is optional and skippable, and saving with just a date always works.
2. **Calm over clever.** Weekly rhythm, plain counts, gentle copy. No streaks, scores, nudges or judgement.
3. **Discreet by default.** Nothing outside the entry flow reveals what is tracked. Optional details stay hidden until the user turns them on.
4. **The user owns the record.** It's private on the device and protected by encryption. It never leaves except as a backup the user makes, and nothing is lost by turning a setting off.

## Accessibility & Inclusion

- **Text and contrast:**
  - large system text up to 200%
  - 4.5:1 contrast for body text, 3:1 for icons and controls
- **Screen readers:** TalkBack and VoiceOver, with labelled controls and announced state.
- **Meaning:** never carried by colour alone.
- **Touch:** 48 px targets.
- **Layout:** keyboard insets respected.
- **Inclusive wording:** "On my period", with no assumptions about the user.
