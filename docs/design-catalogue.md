# morrow: design catalogue

Source: Figma file `poopTracker` (k5nqDgD29IrWJ3nuKYdOLS), Page 1. It has 66 frames in sections 0–9, numbered in the order a person meets the screens. The primary state is both optional-detail settings off; "Details on" frames are variants.

Status shows where each screen is built. **Built** means it's in the app, and the milestone is given in brackets.

## Change log

### 8 November 2026: design pass

These changes were made in Figma by the product owner and catalogued from a full scan of every frame (text and structure) plus screenshots of the changed frames. The direction: less explanatory and reassurance copy, and a shorter add-details flow.

| Area | Frames | Change |
|---|---|---|
| Journal empty | 1.4 | Empty message shortened to "Add an entry whenever you're ready" (dropped "It stays on this phone."). |
| Stool form step | 3.2 | Removed the "ADD DETAILS · OPTIONAL · 1 OF 2" eyebrow and the back arrow. The header is "New entry" with "Skip", over the progress bars. Help text is now "Choose the closest match" (was "Optional. Choose the closest match, or skip. An estimate is fine."). "Skip and save entry" removed, leaving only "Continue". |
| Context step | 3.3 | Removed the eyebrow, the "All of this is optional…" line and the "No account. No cloud syncing." footer. Added "Skip" to the header. "Anything to note?" gains "On my period" and "Feeling sick". |
| History | 4.2–4.6, 4.11 | Removed the "THE JOURNAL" eyebrow, the "Small observations, kept in one place." subtitle and the "N entries · Most recent first" line. "0 entries" still shows when nothing matches (4.5, 4.6). |
| Entry detail | 4.7, 4.8, 4.10 | Removed "Saved on this device · Not shared anywhere". 4.8 also drops every "Optional" label ("Optional detail" under the type, "Ease of passage · Optional" becomes "Ease of passage", and none on Symptoms or Context). |
| Trends | 5.1–5.7 | Removed the "A LITTLE PERSPECTIVE" eyebrow, the "A simple look at each week." subtitle and the "Patterns, not a diagnosis" card. "Optional · Bristol scale" and "Optional · N of M entries" stay on the details-on charts. |
| App lock | 7.2 | Small clean-up in the confirm sheet (a removed element). No change to copy. |

The following decisions were made with the product owner after the scan:
- **Symptoms are removed entirely.** That covers the "Any symptoms?" section, symptom lines on cards, the Symptoms section on entry detail, and "Symptoms you noted" on Trends.
- **"Exercise" is removed** from "Anything to note?".
- **The context step no longer says "optional".** It shows Skip and Save instead, and CLAUDE.md is updated.
- **Optional time (M6.1):** an entry's time can be left out. It defaults to now for today, and to no time for past days.

### 7 November 2026: earlier passes (made from the code side)

- **Contrast:**
  - Muted text is `#666b60` and disabled text `#595e53`.
  - Warm text is `#895943`, and the "TYPE n" labels went from 10 to 11 pt.
  - Switches are outlined when off, with a check mark when on.
- **Stool form on Trends** shows counts only. The "72% were type 3 or 4" headline and the "formed stools" note were removed.
- **Journal home:**
  - the "On-device only" chip is removed
  - the title is "Your journal" and the link reads "See your patterns"
  - there's a week header (‹ This week ›), and future days are greyed out
  - new frame 4.12 shows an earlier week
- **Editor:** the note counter sits under the note box.
- **Severity removed:** "Mild bloating" and "Bloating · Mild" read "Bloating". This is moot now that symptoms are gone.

## Screens

### 0 · Read me
- **0.1 How to read this file:** conventions (journeys, primary state, details on, weekly).

### 1 · First launch (M8, M11)
- **1.1 Welcome:** "A little daily clarity." with three promises (stays on this phone, private by default, keep your own backup), plus Get started, Set up app lock and Restore from a backup. *Not built (M8/M11).*
- **1.2 Confirm to turn on app lock:** the system authentication sheet over Welcome. *M8.*
- **1.3 App lock is on:** confirmation, then Continue. *M8.*
- **1.4 Journal · Empty:** *Built (M5).*

### 2 · Log an entry (details off), all built (M5)
- **2.1 Journal:** week header, strip, stats, Add an entry, this week's list, See your patterns.
- **2.2 Add entry:** When row and note with counter.
- **2.3 Choose date and time:** Today, Yesterday or Other date, then hour, minute and am/pm wheels. *Changes in M6.1 (optional time).*
- **2.4 Saving entry, 2.5 Couldn't save entry, 2.6 Discard this entry?, 2.7 Entry saved.**

### 3 · Log an entry (details on), built (M6)
- **3.1 Add entry · Details on:** Optional details card (Stool form, A little context).
- **3.2 Stool form:** seven Bristol types, Skip and Continue.
- **3.3 A little context:** How did it feel? (Easy, Some straining, Difficult); Anything to note? (After a meal, Coffee, Stress, Low fluids, Medication, On my period, Feeling sick); Your notes; Save entry.
- **3.4 Journal · Details on:** type tile, then "form · ease" on each card.

### 4 · Browse, edit and delete, built (M5, M6)
- **4.1 Day selected, 4.2 History, 4.3 History · Details on** (All types filter), **4.4 Filter entries, 4.5 Search · No results, 4.6 History · Empty, 4.7 Entry detail, 4.8 Entry detail · Details on, 4.9 Edit entry, 4.10 Delete this entry?, 4.11 Entry deleted, 4.12 Journal · Earlier week.**

### 5 · Weekly trends (M7)
- **5.1–5.3:** 4, 12 and 26 weeks, with total, per week, weeks logged and the entries-each-week chart.
- **5.4–5.6 Details on:** adds the stool form counts chart. The "Symptoms you noted" section is removed by the 8 November decision.
- **5.7 Not enough data.**

### 6 · Weekly reminder (M9)
- **6.1 Off, 6.2 Allow notifications?, 6.3 On** (day and time, preview, status), **6.4 Notifications off, 6.5 Reminder notification.**

### 7 · App lock (M8)
- **7.1 Off, 7.2 Confirm to turn on, 7.3 On, 7.4 Locked, 7.5 Couldn't unlock, 7.6 Confirm to turn off.**

### 8 · Settings, privacy and deleting data
- **8.1 Settings, 8.2 Settings · Details on:** the Journal switches are *built (M6)*. The Reminders, Privacy and Data rows come in M8–M10.
- **8.3 Data & privacy, 8.4 Delete all data, 8.5 Confirm to delete, 8.6 Deleting data, 8.7 All data deleted:** *M10.*
- **8.8 Journal unavailable, 8.9 Erase and start fresh?:** *Built (M4).*

### 9 · Back up and restore (M11)
- **9.1 Export a backup, 9.2 Creating backup, 9.3 Native save picker** (documentation only), **9.4 Backup saved, 9.5 Restore from a backup, 9.6 Native file picker** (documentation only), **9.7 Enter passphrase, 9.8 Restoring entries, 9.9 Restore complete, 9.10 Couldn't restore.**

## Known gaps between Figma and the app

- The app has screens Figma doesn't draw: the blocked states other than the key problem (storage unavailable, encryption unavailable, setup failed), the locked placeholder, and the debug-only developer tools.
- Entry detail (4.8) uses a longer type description ("Soft pieces with clear-cut edges") than the stool step (3.2, "Clear-cut edges"). The app uses the step's wording in both places.
