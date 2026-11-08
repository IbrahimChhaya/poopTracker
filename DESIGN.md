---
name: morrow
description: A quiet, private notebook for everyday check-ins.
colors:
  deep-sage: "#3d6552"
  sage-tint: "#e7ede2"
  sage-tint-line: "#ccd5c7"
  on-sage-muted: "#dce6dc"
  cream-paper: "#f7f4ec"
  card-paper: "#fffdf8"
  pencil-line: "#dddcd0"
  ink: "#293b34"
  muted-text: "#666b60"
  muted-icon: "#74796d"
  sand: "#f2e6da"
  clay: "#ac7157"
  clay-text: "#895943"
  rust: "#8a4a32"
  switch-track-off: "#ece9df"
  disabled-surface: "#dcdcd2"
  disabled-text: "#595e53"
typography:
  page-title:
    fontFamily: "Inter"
    fontSize: "30px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-1px"
  detail-time:
    fontFamily: "Inter"
    fontSize: "27px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.8px"
  stat-value:
    fontFamily: "Inter"
    fontSize: "25px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.7px"
  wordmark:
    fontFamily: "Inter"
    fontSize: "23px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-1px"
  headline:
    fontFamily: "Inter"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.25
  title-large:
    fontFamily: "Inter"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.33
  title:
    fontFamily: "Inter"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  title-small:
    fontFamily: "Inter"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.2
  body-large:
    fontFamily: "Inter"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  body:
    fontFamily: "Inter"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  body-small:
    fontFamily: "Inter"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.42
  label-large:
    fontFamily: "Inter"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.2
  label:
    fontFamily: "Inter"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.25
  label-small:
    fontFamily: "Inter"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.2
  eyebrow:
    fontFamily: "Inter"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "1.5px"
rounded:
  sm: "12px"
  md: "14px"
  lg: "16px"
  xl: "18px"
  xxl: "20px"
  sheet: "28px"
  pill: "99px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  page: "24px"
components:
  button-primary:
    backgroundColor: "{colors.deep-sage}"
    textColor: "{colors.card-paper}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    padding: "14px 20px"
    height: "52px"
  button-primary-large:
    backgroundColor: "{colors.deep-sage}"
    textColor: "{colors.card-paper}"
    typography: "{typography.label-large}"
    rounded: "{rounded.lg}"
    height: "54px"
  button-primary-disabled:
    backgroundColor: "{colors.disabled-surface}"
    textColor: "{colors.disabled-text}"
    rounded: "{rounded.md}"
    height: "52px"
  button-secondary:
    textColor: "{colors.deep-sage}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    padding: "14px 20px"
    height: "52px"
  button-danger-outline:
    textColor: "{colors.rust}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    height: "52px"
  button-danger:
    backgroundColor: "{colors.rust}"
    textColor: "{colors.card-paper}"
    typography: "{typography.label-large}"
    rounded: "{rounded.md}"
    height: "52px"
  card:
    backgroundColor: "{colors.card-paper}"
    rounded: "{rounded.lg}"
  entry-card:
    backgroundColor: "{colors.card-paper}"
    rounded: "{rounded.xl}"
    padding: "16px"
  stat-card:
    backgroundColor: "{colors.sage-tint}"
    textColor: "{colors.deep-sage}"
    rounded: "{rounded.xxl}"
    padding: "18px"
  icon-tile:
    backgroundColor: "{colors.sage-tint}"
    textColor: "{colors.deep-sage}"
    rounded: "{rounded.sm}"
    size: "36px"
  icon-tile-warm:
    backgroundColor: "{colors.sand}"
    textColor: "{colors.clay}"
    rounded: "{rounded.sm}"
    size: "36px"
  chip:
    backgroundColor: "{colors.card-paper}"
    textColor: "{colors.ink}"
    typography: "{typography.body-small}"
    rounded: "{rounded.pill}"
  chip-selected:
    backgroundColor: "{colors.sage-tint}"
    textColor: "{colors.deep-sage}"
    rounded: "{rounded.pill}"
  input:
    backgroundColor: "{colors.card-paper}"
    textColor: "{colors.ink}"
    typography: "{typography.body-large}"
    rounded: "{rounded.lg}"
    padding: "16px"
  week-day:
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    rounded: "{rounded.md}"
    height: "72px"
  week-day-selected:
    backgroundColor: "{colors.deep-sage}"
    textColor: "{colors.card-paper}"
    rounded: "{rounded.md}"
  navigation-bar:
    backgroundColor: "{colors.cream-paper}"
    textColor: "{colors.muted-text}"
    typography: "{typography.label-small}"
  navigation-indicator:
    backgroundColor: "{colors.sage-tint}"
    textColor: "{colors.deep-sage}"
    rounded: "{rounded.pill}"
  sheet:
    backgroundColor: "{colors.card-paper}"
    rounded: "{rounded.sheet}"
    padding: "0 24px 36px"
  dialog:
    backgroundColor: "{colors.card-paper}"
    rounded: "{rounded.xxl}"
    padding: "20px"
  toast:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.card-paper}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
  error-banner:
    backgroundColor: "{colors.sand}"
    textColor: "{colors.rust}"
    rounded: "{rounded.md}"
    padding: "14px"
  stool-form-tile:
    backgroundColor: "{colors.sand}"
    textColor: "{colors.clay-text}"
    rounded: "{rounded.sm}"
    width: "58px"
---

# Design System: morrow

## Overview

**Creative North Star: "The Quiet Notebook"**

morrow should feel like a small paper notebook kept somewhere private. The pages are cream, the writing is deep sage ink, and nothing on a page performs. It's discreet, plain and tidy. Someone glancing at the screen should see an ordinary, well-kept notes app, never a medical product and never something that draws attention. The craft is in the restraint: steady 24 px margins, soft rounded paper shapes, one green, and type that does the work through weight rather than decoration.

The density is calm rather than sparse. There's one primary action per screen (the large "Add an entry" button, or "Save"). Information is grouped into outlined paper cards on a slightly darker cream page. Everything is flat: depth comes from paper on paper, never from shadows. Colour is held back so that the single green carries meaning: it marks what you can do and what you've chosen.

The rejected references are clinical white-and-blue health-app styling, gamified colour (streaks, badges, celebration palettes), and anything loud enough to reveal what's being tracked.

**Key Characteristics:**
- Cream paper page (`cream-paper`) with brighter paper cards (`card-paper`) outlined by a 1 px pencil line.
- A single accent, Deep Sage, used for actions, selection and the wordmark.
- Inter only, in three weights (400, 500, 600). Hierarchy comes from size and weight, never from colour or decoration.
- Flat everywhere: no drop shadows at rest or on interaction.
- Rounded, friendly geometry (12–20 px corners, pill chips).
- Warm clay and sand appear only around optional details and the patterns link. Rust is kept for destructive actions and errors.
- State is always shown twice: by colour and by a check mark, outline, weight or position.

## Colors

A warm, paper-and-ink palette: cream neutrals, one deep sage accent, and a small warm family that stays at the edges.

### Primary
- **Deep Sage** (#3d6552): the only accent. Used for primary and secondary buttons, the selected day in the week strip, the today outline, selected chips and their check marks, the navigation indicator's icon and label, links ("Edit", "Show earlier entries", "Skip"), stat values and the morrow wordmark. It's 6.0:1 on Cream Paper and 6.5:1 behind Card Paper text.
- **Sage Tint** (#e7ede2): the quiet green surface. Used for the stat card, icon tiles, the selected chip fill, the navigation indicator pill, the date-range chip and the picker highlight. Deep Sage text on it is 5.5:1.
- **Sage Tint Line** (#ccd5c7): the divider inside Sage Tint surfaces, such as between the two stat-card figures.
- **On-Sage Muted** (#dce6dc): secondary text on a Deep Sage surface (the weekday letter on the selected day).

### Tertiary
- **Sand** (#f2e6da): the warm surface. Used for error banners, the warm icon tile (Delete all data, the "See your patterns" link), the stool form tile and the entry-detail date card.
- **Clay** (#ac7157): warm icons and the stool form drawings on Sand. It's 3.3:1, so it's for icons only and never for text.
- **Clay Text** (#895943): small warm text, such as "TYPE 4" and the uppercase date on entry detail. It's 4.8:1 on Sand.
- **Rust** (#8a4a32): destructive and error. Used for danger buttons, "Delete this entry", error titles and the error icon. It's 5.5:1 on Sand and 6.7:1 on Card Paper.

### Neutral
- **Cream Paper** (#f7f4ec): the page background, plus the navigation bar and the picker well.
- **Card Paper** (#fffdf8): cards, sheets, dialogs, inputs and unselected chips. It's also the text colour on Deep Sage and Ink.
- **Pencil Line** (#dddcd0): the 1 px outline on every card, input and chip, plus dividers and the sheet handle.
- **Ink** (#293b34): primary text (10.8:1 on Cream Paper). It's also the toast background.
- **Muted Text** (#666b60): secondary text such as subtitles, dates, "No note", captions and labels. It's darker than the original Figma muted value so it reaches 4.5:1 on every surface.
- **Muted Icon** (#74796d): chevrons, inactive navigation icons, the off-switch outline and thumb, and the search icon. It's 3:1 or better, so icons only.
- **Switch Track Off** (#ece9df): the fill of an off switch, with the contrast carried by its Muted Icon outline.
- **Disabled Surface** (#dcdcd2) and **Disabled Text** (#595e53): busy or disabled primary buttons, such as "Saving…" (4.8:1).

### Named Rules
**The One Green Rule.** Deep Sage is the only accent and it always means "you can act here" or "this is chosen". Never add a second accent hue for emphasis.

**The Text Passes Rule.** Every colour used for text reaches 4.5:1 on the surface it sits on. Muted Icon and Clay are icon-only colours: if a colour is below 4.5:1, it doesn't carry words.

**The Warm Edge Rule.** Sand and Clay are for optional detail and gentle signposts, and Rust is for destruction and failure. None of them tints primary actions or ordinary content.

## Typography

**Display Font:** Inter (bundled; no network fonts)
**Body Font:** Inter
**Label Font:** Inter

**Character:** One neutral, highly legible sans in three weights. It reads as a plain, competent notebook: confident titles in SemiBold with slightly tightened tracking, and calm Regular body text.

### Hierarchy
- **Page title** (600, 30 px, 1.2, −1 px tracking): screen titles such as "Your journal", "Your history", "Settings" and "Entry details".
- **Detail time** (600, 27 px, 1.2, −0.8 px): the large time on entry detail.
- **Stat value** (600, 25 px, −0.7 px, Deep Sage): the stat-card figures ("5 entries", "1:35 pm").
- **Wordmark** (600, 23 px, −1 px, Deep Sage): "morrow", always lower case, next to the sprout mark.
- **Headline** (600, 20 px, 1.25): editor and step titles, and "What was the form?".
- **Title large** (600, 18 px, 1.33): dialog and sheet titles.
- **Title** (600, 16 px, 1.2, −0.3 px): section headings ("This week's journal", "How did it feel?") and the week-strip date numbers.
- **Title small** (600, 15 px, 1.2): entry card titles ("Today · 1:35 pm").
- **Body large** (400, 15 px, 1.45): inputs, option labels, setting row titles (in 500) and blocked-screen copy.
- **Body** (400, 14 px, 1.5): running copy and dialog messages.
- **Body small** (400, 12 px, 1.42, Muted Text): card summaries, row subtitles and chip labels (chips in Ink, or Deep Sage at 600 when selected).
- **Label large** (600, 16 px): button labels.
- **Label** (500, 12 px, Muted Text): group labels above cards ("Journal", "Optional details") and "Note (optional)".
- **Label small** (400, 11 px, Muted Text): captions, stat labels, weekday initials, navigation labels and the character counter.
- **Eyebrow** (600, 11 px, 1.5 px tracking, upper case, Deep Sage): reserved, and now rarely used after the 8 November design pass.

### Named Rules
**The Three Weights Rule.** Inter at 400, 500 and 600 only. Emphasis is weight or size, never italics, never a second family, never colour alone.

**The Sentence Case Rule.** Everything is in sentence case. Upper case is limited to two cases: the "TYPE n" tile label and the date line on entry detail.

**The Scales With You Rule.** All text follows the system text size up to 200%. Layouts grow, wrap or scroll rather than clip, and a single-line figure may shrink to fit only when there's no room.

## Layout

There's a single column on a phone. Content sits inside 24 px side margins (`page`), with 12 px above the first item. Spacing is on a 4 px grid: 8 px inside groups, 12 px between list cards, and 24 px between sections. Lists are long scrolling columns. Fixed footers (editor actions) sit on Cream Paper above a 1 px Pencil Line and stay above the keyboard.

Each screen has one primary action, full width, at the top of the content (journal) or in the footer (editor, steps). Grouped settings live in a single outlined card, with 1 px dividers between rows.

### Named Rules
**The Steady Margin Rule.** 24 px side margins on every screen, including sheets and dialogs (whose content sits 20–24 px inside the card). Nothing touches the screen edge except the navigation bar and full-bleed sheets.

**The Room To Grow Rule.** Heights are minimums, never fixed. Rows, cells and buttons grow with large text. Minimum heights are 52 px for buttons, 72 px for day cells and 48 px for every touch target.

## Elevation & Depth

morrow is flat. Nothing has a drop shadow, at rest or in response to state: the theme sets elevation to 0 for buttons, chips, sheets, dialogs, the navigation bar and toasts. Depth is conveyed by layering paper on paper. A brighter Card Paper surface sits on the Cream Paper page, outlined by a 1 px Pencil Line, and quiet emphasis uses Sage Tint or Sand. Modal layers dim the page with an Ink scrim at 50% opacity, never with shadow.

### Named Rules
**The Paper Flat Rule.** No shadows. If a surface needs to stand apart, give it a different paper tone or a Pencil Line, not a shadow.

## Shapes

The shapes are soft and friendly, with nothing sharp. Corner radii follow the size of the object:
- **Icon tiles and the stool form tile:** 12 px.
- **Buttons, day cells, banners and the toast:** 14 px.
- **Grouped cards, inputs and the large "Add an entry" button:** 16 px.
- **Entry and empty-state cards:** 18 px.
- **The stat card, dialogs and the entry-detail date card:** 20 px.
- **Sheets:** 28 px on the top corners.
- **Chips, badges, the navigation indicator and switches:** fully round.

Borders are a single 1 px Pencil Line. Selected things swap the line for Deep Sage (chips, the today outline) or fill with Deep Sage (the selected day). The off switch uses a 2 px Muted Icon outline.

### Named Rules
**The Soft Corner Rule.** Every container is rounded, and larger containers get larger radii. No square corners, no mixed radii on one object.

## Components

The components should feel tidy and tactile, like well-made stationery: plain shapes, clear states and nothing ornamental.

### Buttons
- **Shape:** gently rounded (14 px). The large journal action is 16 px.
- **Primary:** Deep Sage fill, Card Paper label in label-large, 14 × 20 px padding, at least 52 px tall (54 px for the large variant), full width. The label can sit beside an icon ("+ Add an entry").
- **Secondary:** transparent, with a 1 px Deep Sage outline and Deep Sage label. Used for "Clear filters", "Cancel" and "Keep entry".
- **Danger outline:** transparent, with a 1 px Rust outline and Rust label. Used for a destructive choice where the safe choice comes first ("Discard").
- **Danger:** Rust fill with Card Paper label, only for a confirmed destructive action ("Delete entry", "Erase everything").
- **Busy / disabled:** Disabled Surface fill with Disabled Text label. A busy button shows a small spinner and "Saving…", and can't be tapped again.
- **Pressed:** a soft ink ripple (Card Paper at 12% on fills, Deep Sage at 8% on outlines). No lift and no shadow.
- **Text links:** Deep Sage label, SemiBold 14 px ("Edit", "Skip", "Show earlier entries"). Rust is used for "Delete this entry".

### Chips
- **Style:** fully round. Unselected chips are Card Paper with a 1 px Pencil Line and an Ink label in body-small.
- **Selected:** Sage Tint fill, a 1 px Deep Sage outline, a Deep Sage check mark, and a Deep Sage label in SemiBold. Selection shows in three ways: fill, check mark and weight.
- **Behaviour:** tapping a chosen chip again clears it. Single-choice groups (ease) and multi-choice groups (tags) look the same.

### Cards / Containers
- **Corner style:** 16 px for grouped cards, 18 px for entry cards and 20 px for the stat card.
- **Background:** Card Paper. The stat card uses Sage Tint; the entry-detail date card and error banner use Sand.
- **Shadow strategy:** none (see Elevation & Depth).
- **Border:** 1 px Pencil Line on Card Paper surfaces. None on tinted surfaces.
- **Internal padding:** 16 px for entry cards; 14 × 16 px for setting rows (icon tile, then a 12 px gap, then text, then a trailing chevron or switch); 18 px for the stat card.

### Inputs / Fields
- **Style:** Card Paper fill, 1 px Pencil Line, 16 px corners, 16 px padding, and body-large Ink text with a Muted Text hint.
- **Focus:** the outline becomes Deep Sage at 1.5 px. No glow.
- **Counter:** "21 / 500" in label-small, under the field and aligned right.
- **Search:** the same field with a Muted Icon search glyph and a clear button.

### Navigation
- **Style:** a bottom bar on Cream Paper with a 1 px Pencil Line above, holding four destinations (Journal, History, Trends, Settings).
- **Default:** a Muted Icon glyph over a label-small label in Muted Text.
- **Active:** a Sage Tint pill behind a Deep Sage icon, with the label in Deep Sage SemiBold.
- **Behaviour:** the bar grows with the text size. Tapping the active tab returns to its first page.

### Week Strip (signature)
- A Monday-to-Sunday row of day cells, each at least 72 px tall with 14 px corners, showing the weekday initial in label-small, the date number in title, and a 4 px entry dot.
- **Today:** a 1 px Deep Sage outline.
- **Selected day:** a Deep Sage fill with a Card Paper number, an On-Sage Muted initial and a Card Paper dot.
- **Future days:** Muted Text with no dot, and not selectable.
- **Earlier weeks:** the strip swipes horizontally. Above it, a "‹ This week ›" header does the same thing for people who can't swipe. The tappable area of each day is a full seventh of the row, even though the visible cell keeps a 5 px gap.

### Stat Card (signature)
A Sage Tint panel (20 px corners, 18 px padding) holding two figures: the entry count for the week on screen, and the most recent entry. Each figure is in stat-value Deep Sage over a label-small caption, separated by a 1 px Sage Tint Line.

### Sheets, Dialogs and Toasts
- **Sheet:** Card Paper with 28 px top corners, a 40 × 4 px Pencil Line handle and a title-large heading. Content sits 24 px in from the sides and 36 px above the bottom.
- **Dialog:** Card Paper with 20 px corners and 20 px padding, a title-large title and body message, and full-width stacked buttons. The safe choice comes first for discards; the destructive filled button comes first for deletes.
- **Toast:** Ink with Card Paper text and a check icon, 14 px corners, floating above the navigation bar. It only appears after the change has been saved.

### Stool Form Tile and Drawings
- **Drawings:** simple flat shapes painted in Clay for each Bristol type. They're decorative and hidden from screen readers.
- **Tile:** 58 px wide on Sand, with "TYPE n" in Clay Text (11 px, 600).
- **Where they appear:** only inside the entry flow, journal and History cards, and entry detail, and only when the Stool form setting is on.

## Do's and Don'ts

### Do:
- **Do** put content on Cream Paper (#f7f4ec) in Card Paper (#fffdf8) cards outlined by a 1 px Pencil Line (#dddcd0).
- **Do** keep Deep Sage (#3d6552) as the one accent, for actions, selection, links and the wordmark.
- **Do** show every state twice: colour plus a check mark, outline, weight, position or text ("Off", "No time").
- **Do** use Muted Text (#666b60) for secondary text, and keep Muted Icon (#74796d) and Clay (#ac7157) for icons only.
- **Do** let every row, cell and button grow with system text up to 200%, with targets of at least 48 px.
- **Do** keep one full-width primary action per screen, at least 52 px tall with 14 px corners.
- **Do** use neutral wording and the plain sprout-and-wordmark identity outside the entry flow.

### Don't:
- **Don't** add drop shadows, glows or lifted hover states. morrow is flat paper.
- **Don't** introduce a second accent colour, gradients, or celebratory and gamified colour (streaks, badges, confetti).
- **Don't** use clinical white-and-blue health-app styling, medical iconography, or imagery that reveals what's tracked outside the entry flow.
- **Don't** set text in Muted Icon, Clay, Sage Tint Line or any colour below 4.5:1 on its surface.
- **Don't** use weights other than 400, 500 and 600, italics, or a second typeface.
- **Don't** hard-code colours in widgets. Use the theme tokens (`MorrowColors`, `ColorScheme`) so a dark palette can follow after v1.
- **Don't** use upper case beyond the "TYPE n" tile and the entry-detail date line.
