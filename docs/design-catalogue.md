# morrow: design catalogue

Source: Figma file `poopTracker` (k5nqDgD29IrWJ3nuKYdOLS), Page 1. The page has two columns. **Approved design** (left) holds sections 0–9: every approved screen, built or not, numbered in the order a person meets the screens. **Superseded and rejected** (right) holds a read-me, the screens approved designs replaced (named "Old · …") and rejected drafts. The primary state is both optional-detail settings off; "Details on" frames are variants.

Status shows where each screen is built. **Built** means it's in the app, and the milestone is given in brackets. **To build** means approved but not in the app yet.

## Change log

### 8 November 2026: one-tap entry approved (M6.3)

First drawn as section 11.2, then merged into journeys 2–4 (see the sections below), with four new frames: 2.6 Couldn't save changes, 2.7 Discard changes?, 4.7 Entry page (details off) and 4.9 Delete this entry?. Sections 11 and 11.1 were rejected and moved to the right-hand column. Frame numbers below are the original 11.2 numbers.

| Frame | What it shows |
|---|---|
| 11.2.1 Journal | Tap "Add an entry". |
| 11.2.2 Entry added | Saved instantly with the current time; "Added to today" with Undo; the button reads "Saved", greyed out. |
| 11.2.3 Change the time | The existing date and time sheet over the entry page. |
| 11.2.4 Changed | A changed time and a note: the button reads "Save", with "Unsaved changes". |
| 11.2.5 Journal after Save | The updated entry at the top of the week. |
| 11.2.6 Details on | Two cards, Context then Stool form. |
| 11.2.7 Context page | The details sheet on page 1 of 2: segmented ease, tags in two rows, Clear, Next. |
| 11.2.8 Stool form page | Page 2 of 2: the seven types, Clear, Done. |
| 11.2.9 Details added | The cards summarise the choices; the button still reads "Saved". |
| 11.2.10 Older entry | The same page opened from the journal: no banner, Delete this entry, "Saved". |

"A little context" is renamed "Context" in these frames and in the read-me. The current-design frames (3.x, 4.7–4.9, 8.2) keep the old screens and name until M6.3 ships.

### 8 November 2026: critique pass (M6.2)

Mocked in a new section, **10 · Critique pass**, after an `/impeccable critique` of the journal screens, approved by the product owner and built in M6.2. Section 10 has since been merged: 10.2 is now 2.9 and 10.3 is now 4.2, and 10.1 and 10.4 were superseded by the one-tap entry designs.

| Frame | Change |
|---|---|
| 10.1 Journal | Tighter spacing above the list; stat values at 20 px on one line; cards without a note drop the "No note" line. |
| 10.2 Journal at 130% text | The two stats stack, each value kept on one line with its unit. |
| 10.3 History | An untimed entry is titled "Entry" (the day is already the group heading); no "No note" line. |
| 10.4 Entry detail | Title at the 20 px headline size, like "New entry". The time leads, then the date in sentence case; no Sand date card, so the note leads. |

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

### 2 · Log an entry (details off): one-tap entry, built (M6.3)
- **2.1 Journal:** tap "Add an entry" (critique-pass style, built in M6.2).
- **2.2 Entry added:** saved straight away with the current time; "Added to today" with Undo; close (×); the button reads "Saved", greyed out with a tick.
- **2.3 Change date and time:** the date and time sheet over the entry page.
- **2.4 Choose a date · No time:** the same sheet with "Record a time" off (built, M6.1).
- **2.5 Changed · Save active:** a changed time and a note; "Unsaved changes" above "Save". The Undo banner stays until you leave the page.
- **2.6 Couldn't save changes:** error banner; the changes stay; "Try again".
- **2.7 Discard changes?:** leaving with unsaved changes. "Your entry is already saved. Only the changes you just made to it will be lost."
- **2.8 Journal · After saving:** the updated entry at the top of the week.
- **2.9 Journal · Large text (130%):** the stats stack (built, M6.2).
- **2.10 Couldn't add an entry:** a failed one-tap save; an error banner under "Add an entry" reads "Nothing was saved. Try again."
- **2.11 Undo after editing:** Undo stays on the page until you leave. After an edit it asks "Undo this entry?" ("It will be removed, along with the changes you just made.").

### 3 · Log an entry (details on): built (M6.3)
- **3.1 Entry added · Details on:** two cards, Context then Stool form.
- **3.2 Details sheet · Context:** page 1 of 2. "How did it feel?" as a segmented control; "Anything going on?" tags in two rows; Clear; Next. The subtitle reads "Saved as you choose".
- **3.3 Details sheet · Stool form:** page 2 of 2. The seven types, Clear, Done. Swipe moves between pages.
- **3.4 Details added:** the cards summarise the choices; the button still reads "Saved".
- **3.5 Journal · Details on:** type tile, then "form · ease" on each card (built, M6).
- **3.6 Details sheet · One setting on:** a single page with no step bar; the button reads Done.

### 4 · Browse, change and delete entries (M5, M6, M6.2, M6.3)
- **4.1 Journal · Day selected:** *Built (M5).*
- **4.2 History:** an untimed entry is titled "Entry". *Built (M6.2).*
- **4.3 History · Details on** (All types filter), **4.4 Filter entries, 4.5 Search · No results, 4.6 History · Empty:** *Built (M5, M6).*
- **4.7 Entry page:** an older entry opened from the journal or History. It's the same page as 2.2, without the banner, plus "Delete this entry". *Built (M6.3); replaces Entry details and Edit entry.*
- **4.8 Entry page · Details on:** with the Context and Stool form cards. *Built (M6.3).*
- **4.9 Delete this entry?:** confirmation over the entry page. *Built (M6.3).*
- **4.10 Entry deleted, 4.11 Journal · Earlier week:** *Built (M5).*

### 5 · Weekly trends, built (M7)
- **5.1–5.3:** 4, 12 and 26 weeks, with total, per week, weeks logged and the entries-each-week chart.
- **5.4–5.6 Details on:** adds the stool form counts chart. The "Symptoms you noted" section is removed by the 8 November decision.
- **5.7 Not enough data.**

### 6 · Weekly reminder (M9)
- **6.1 Off, 6.2 Allow notifications?, 6.3 On** (day and time, preview, status), **6.4 Notifications off, 6.5 Reminder notification.**

### 7 · App lock (M8)
- **7.1 Off, 7.2 Confirm to turn on, 7.3 On, 7.4 Locked, 7.5 Couldn't unlock, 7.6 Confirm to turn off.**

### 8 · Settings, privacy and deleting data
- **8.1 Settings, 8.2 Settings · Details on:** the Journal switches are *built (M6)*. Figma now says "Context" (was "A little context") with new descriptions; built in M6.3. The Reminders, Privacy and Data rows come in M8–M10.
- **8.3 Data & privacy, 8.4 Delete all data, 8.5 Confirm to delete, 8.6 Deleting data, 8.7 All data deleted:** *M10.*
- **8.8 Journal unavailable, 8.9 Erase and start fresh?:** *Built (M4).*

### 9 · Back up and restore (M11)
- **9.1 Export a backup, 9.2 Creating backup, 9.3 Native save picker** (documentation only), **9.4 Backup saved, 9.5 Restore from a backup, 9.6 Native file picker** (documentation only), **9.7 Enter passphrase, 9.8 Restoring entries, 9.9 Restore complete, 9.10 Couldn't restore.**

### 10 · Diagnostics, built (M7.5)
- **10.1 Settings · Diagnostics:** a new Support group with the Diagnostics row.
- **10.2 Diagnostics:** what is recorded and never recorded, the "Keep a diagnostic log" switch, recent events, "Save a copy" and "Share by email".
- **10.3 Share the log?:** a confirmation before anything leaves the phone.
- **10.4 Native share sheet:** documentation only; the email app sends the file.
- **10.5 Log saved, 10.6 Diagnostics · Log off.**
- **10.0:** a note on what the feature adds. *Built in M7.5; successful journal actions are not logged, so the example rows "Entry added" and "Entry page opened" don't occur.*

## Superseded and rejected column

- **Superseded and rejected · read me:** how the column works.
- **Superseded · screens replaced by approved designs:**
  - **Replaced by one-tap entry and the entry page (M6.3):** old 2.2–2.7, 3.1–3.3, 4.7–4.10, and the 11.2 note.
  - **Replaced by the critique pass (M6.2):** old 2.1 and 4.2, the section 10 frames (10.1, 10.4) and the 10.0 note. 10.2 and 10.3 moved into journeys 2 and 4.
- **Rejected · Context on the editor (was 11.1)** and **Rejected · Context as a full sheet (was 11).**

## Known gaps between Figma and the app

- Some older journal and History frames still use stat values larger than the M6.2 20 px. The "No note" lines and "No time" titles in day lists were fixed on 8 November.
- The app has screens Figma doesn't draw: the blocked states other than the key problem (storage unavailable, encryption unavailable, setup failed), the locked placeholder, and the debug-only developer tools.
