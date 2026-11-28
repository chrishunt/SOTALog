# SOTA Log Design Document

This is the authoritative reference for SOTA Log's design philosophy and intent. Read this before working on any feature or bug. For implementation details, read the code.

---

## Core Philosophy

**Simplicity is the primary feature.** Every decision filters through this. If a change adds complexity, configurability, or cognitive load — it doesn't belong here.

- **One happy path, perfected.** No settings screen. No user-configurable options. We make the right choice so the operator doesn't have to.
- **Elegant, not minimal.** Simple doesn't mean ugly or bare. It means the right information at the right time with zero friction.
- **Instantly usable.** A ham should be able to open this app and start logging without reading a single instruction.
- **CW, SSB, and FM.** Mode auto-derives from frequency (CW sub-band, SSB sub-band, or FM sub-band on 2m/6m). RST defaults adjust to match (599 for CW, 59 for voice modes). Don't add support for other modes.
- **Offline-first.** Everything works without internet. All data lives in the local GRDB database. Network operations (QRZ sync, spot fetching, reference downloads) happen only when the user explicitly triggers them.
- **Field-optimized.** Operators use this on summits and in parks, often in cold/wind/rain. Touch targets must be large. Interactions must be minimal. The QSO entry form is the critical path — callsign field auto-focuses, keyboard Send saves from any field, haptic feedback confirms saves.

---

## What NOT to Build

Explicit guardrails — if you're considering any of these, stop and reconsider:

- **Settings or preferences screens.** There's nothing to configure.
- **Mode pickers or multi-select.** The mode chip cycles CW → SSB → FM → CW with a single tap — never a dropdown or multi-option selector.
- **Complex configuration options.** We choose the right default.
- **Features that require explanation.** If it needs a tooltip or help text, it's too complex.
- **Decision points in the logging flow.** The operator's only job is: type callsign, press Send.
- **Automatic background network requests.** The user controls when the radio goes online.
- **Undo/confirmation dialogs in the save path.** Haptic feedback is the confirmation. Speed matters more than safety nets on a reversible action.
- **An Android app.** We had one and dropped it: nobody used it, and keeping it in step with iOS cost a port of every change. The code is in git history.

---

## The Critical Path: Logging a QSO

This is the most important flow in the app. Protect its speed and simplicity above all else.

### Why every detail matters

The operator is sitting on a cold summit or crouched at a picnic table in a park. They're copying Morse code by ear at 20+ WPM. They have maybe 2 seconds between finishing a contact and calling the next station. The app must be an extension of their muscle memory, not a distraction.

### The flow

1. **Callsign entry** — The callsign field is auto-focused on appear. It's the dominant visual element — big, bold, monospaced. The operator types the callsign they just worked. Additional tokens (RST, frequency, QTH, references) can be space-separated in the same field via the OmniField. The placeholder shows a realistic example (`W1AW 59 59 CA W6SD133`) so operators discover the OmniField's capabilities.

2. **Auto-populate** — Name, QTH and grid fill field by field, highest authority first: what the operator typed, a live QRZ lookup, the newest contact in the log that has the field, and for QTH the callsign prefix. Blanks never erase a lower source. Nothing is cached: the log is read directly, so a QRZ download, edit or delete is reflected at once and works offline. A "times worked" badge appears for repeat contacts.

3. **Sensible defaults** — Frequency persists from the previous QSO (you're on the same frequency). Mode is derived from frequency (CW, SSB, or FM sub-band). RST defaults to 599 for CW, 59 for voice modes. Band is derived from frequency. Date and time are stamped at save.

4. **Metadata strip** — Above the callsign, the panel separates who the other station is from how you worked them. The station band runs edge to edge across the top on a raised surface: each callsign list's note, then the name, large, with QTH and grid beside it in gray. It appears only when it has something to show. Below it, a compact chip cloud holds what is set for this contact, in stable order: time (when set), frequency, mode, RST sent, RST received, park/summit references with validation checkmarks. Chips keep their natural size and wrap to more rows when they don't fit; they never truncate or reorder. The name is cut off rather than wrapped, and QTH and grid move under it when it is too long to share the line. Tap any value to edit it inline: its line or the chip row becomes a text field. A faint dotted underline marks the name, QTH and grid as tappable, which sets them apart from the read-only notes without bringing back the chips' capsules. The order puts what moves farthest from the keyboard: the panel grows upward, so the chips stay put for tapping and the name line sits right above them, while extra notes only push upward. Editing a logged contact adds a full-width orange Editing strip with Cancel above the band, the same shape as the band, and tints the row being edited in the log, so it's clear which contact is changing.

   Decided against:
   - **Name, QTH and grid as chips**: everything was the same size and gray, so the person read as one more setting beside 599 and CW, and a lookup filling them in reflowed the chips.
   - **The station in a floating card**: clear, but taller and fussier than a band, and its inset takes width from long notes.
   - **The name above the notes**: it reads more naturally, but every list added would move the name.

5. **Save** — Keyboard Send from any field (callsign or metadata strip). Haptic fires. Fields clear. Focus returns to callsign. Frequency is preserved. The operator is immediately ready for the next contact.

### What to protect

- **No extra taps.** "Contact finished" to "ready for next" must be one keyboard press.
- **No modals or alerts.** Nothing blocks the flow.
- **Frequency persists.** The operator doesn't re-enter frequency between QSOs.
- **Focus returns to callsign.** Always. After save, after edit cancel, after spot prefill.

---

## Design Conventions

### Color has meaning

Colors are semantic, not decorative:

- **Orange** = active / editing / incomplete (editing state, incomplete activation progress)
- **Green** = valid / complete / POTA (checkmarks, completed POTA activations, POTA icons)
- **Blue** = SOTA (summit icons, completed SOTA activations)
- **Red** = error, and nothing else

New UI elements should follow these meanings. Don't use color for decoration.

### Typography principles

- Callsigns are always monospaced — alignment matters in lists and the callsign field is the dominant visual element on screen.
- Numbers that align (times, frequencies, counts) use monospacedDigit.
- Labels are small and secondary — visible but never competing with data.

### Data display consistency

The same data type must look the same on every screen. Bands are always uppercase ("20M"). POTA icons are always green; SOTA icons are always blue. Dates, times, frequencies, and references use the same format everywhere they appear. Subtle styling differences (font size, weight) are fine when context demands it, but the data's format and color meaning must not change between views. Always use the app's semantic color tokens (`Color.appOrange`, `Color.appGreen`, etc.) — never raw system colors.

### Field conditions drive sizing

Touch targets must be large enough for cold, gloved, one-handed operation. The metadata strip segments are tappable — each opens an inline text field for editing. List rows are full-width tap targets. The entry panel is pinned at the bottom of the screen, directly above the keyboard, where thumbs naturally rest.

### Haptic as confirmation

A success haptic on save is the only confirmation. No toasts, no banners, no modals. The operator feels it and moves on.

---

## Key Design Decisions

### The OmniField

The callsign field is also a command line. Space-separated tokens after the callsign are parsed as RST, frequency, mode (CW/SSB/FM), QTH, Maidenhead grid, UTC time (trailing Z, e.g. `1432Z`), or P2P/S2S references. This lets a skilled operator log an entire QSO without leaving a single text field. Unrecognized tokens are silently ignored — never show parse errors in the logging flow.

**Tokens apply on space:** A token after the callsign takes effect only once a space follows it, on Send, or when a chip is opened to edit (so the chip edit is the latest input and wins, and an RST token left in the field doesn't undo it). A CW message key sends what is typed, unfinished token included, without applying it, so a `?` tapped mid-call leaves the call to be finished in place. The token still being typed changes nothing, so `VA3XYZ` is never read as the state `VA` along the way, and its chip appears when the space is typed. The callsign itself is looked up a moment after it stops changing, without waiting for a space, so the name and DUPE badge show while the contact is still on the air.

**Token consumption:** When a recognized token (frequency, QTH, grid, time, park ref, summit ref) applies, it is consumed — stripped from the callsign field and "moved" to the metadata strip. RST tokens remain in the field, and the callsign stays at the front, except that a correction replaces it (below). This keeps the omnibox clean: type `W1AW 59 55 14.060 NC ` and the field shows `W1AW 59 55` while the metadata strip displays the consumed values.

**Correct the callsign by retyping it:** A whole callsign typed at the end replaces the first token once a space follows it (or on Send), and leaves the cursor at the end. A callsign further left is older text and is left alone, so a new call typed in front of the old one is kept. `K6ABC 55 K6ABD ` becomes `K6ABD 55 `, and a tail-end catch `ABC 55 K6ABC ` becomes `K6ABC 55 `. The callsign never moves from the front, RSTs are kept, and nothing needs the cursor moved back. Something that can't be a whole callsign (`K6`, `ABC`, `P2P`) changes nothing; anything shaped like one, even `K6A`, replaces the call once a space follows. The previous station's looked-up name, QTH, grid, badges and spot-filled references are dropped, keeping anything the operator typed. References from a tapped spot or a saved QSO being edited stay, since a correction there usually fixes a misspelled call. There is no clear button: holding delete clears the field, and an empty callsign resets the contact.

### Manual overrides are respected

If the operator explicitly provides a value — whether by editing a field directly or via the OmniField — auto-populate won't overwrite it. This resets after each save. The principle: never fight the operator. The most recent explicit input always wins.

### Time is stamped, not asked — but always correctable

New QSOs stamp date and time at save; time is never a decision point in the logging flow. For contacts logged after the fact, the operator can back-time at entry with a time token (`1432Z`) or fix it later: tap the QSO row to edit, then tap the time chip that appears first on the metadata strip. The chip only exists when it has a value (editing, or a typed token), so the entry panel stays clean during live logging. Invalid time input quietly reverts — same rule as reference validation. The QSO list orders by QSO time, not entry order, so a corrected time visibly moves the row to its chronological place. Dates are not editable in-app; that edge case (crossing UTC midnight) is left to the program websites.

### Spots feed directly into logging

Spots live in a half-sheet accessible from ActiveLogView's toolbar (antenna icon). The sheet starts at half-height (`.medium` detent) and expands to full. Tapping a spot dismisses the sheet and prefills the QSO entry form with the spot's callsign, frequency, and references. The round-trip is two taps: antenna button → tap spot → log → repeat. There is no dedicated Spots tab — viewing spots without a log open is useless.

### Validation is quiet

POTA and SOTA reference inputs validate against the local database. Valid references show a checkmark in their type color (green for POTA, blue for SOTA) and the resolved name. Invalid references show nothing — no error state, just absence of confirmation. Don't punish the operator for typing.

### Dupes are keyed the way the QSO is saved

The DUPE badge means saving would write a row that matches one already in this log on callsign, band, mode, and the other station's summit and park references. The same station worked again from a different summit or park is a new contact — S2S and P2P credit is per reference — so it is not a dupe. The badge is information, not gatekeeping; the operator can always save.

### Callsign lists mark people, one emoji per list

Club members and friends are marked wherever a callsign appears. The operator adds a list on the Sync tab by pasting a link to a file in Ham2K PoLo's callsign notes format, so one file serves both apps. Lists are stored for offline use and download only when added or when their row's refresh button is tapped, like the reference databases.

Each list has one emoji, suggested from the file, and no two lists share one, so a mark always says which list someone is on. The emoji and name can be changed because they are the operator's own labels: a mark only works at a glance if it means something to them, and the suggestion just saves the step when it fits. While logging, the emoji and the list's note about the station sit on their own read-only line at the top of the station band, one line per list, with the emoji in a fixed column so the notes line up. The note is what the list says about someone, which matters most offline with a station never worked, when there is no name from QRZ or the log. It is free-form, not a name, so it is only shown: never filled into the name or saved on the contact. A blank note shows the list's name, so an emoji is never unexplained. Each line is cut off rather than wrapped, so each list stays one line and a long note can't make the band taller. On logged rows the emoji goes in front of the person's name, and spots have no name, so it follows the callsign there. Nothing is attached to the callsign field, which changes with every keystroke.

A station shows every list it is on, in the operator's order of the lists, because that order decides which note leads. New lists go last. Edit in the Callsign Lists header shows the system's delete and reorder controls, as Settings does for preferred languages; it sits on the section rather than the navigation bar because nothing else on the Sync tab is edited that way. Pressing and holding a row drags it too, and each row has Move Up and Move Down for VoiceOver, which reads every reorder handle alike.

Decided against:
- **A cap on lists per station**: a cap of three hid a fourth list without saying so. A station can only be on as many lists as the operator added, and eight fit on the smallest iPhone: the band grows upward, and the spot row cuts marks off rather than wrapping.
- **A footer saying marks and notes follow this order**: it is help text, and the order shows the moment a listed station is logged.
- **An emoji per entry**, as PoLo does: marks from different lists become impossible to tell apart.
- **Using the note as the name when nothing else gives one**: it is free-form text, and would be saved, exported and uploaded as if it were a name.
- **All lists' notes on one line**: the second list's note was cut off almost at once.
- **Folding a note that repeats the name into the name line**: the note is the list's words and the name is the contact's, so they stay separate even when they match.
- **Notes on logged rows and spots**: they are for the moment of logging, and would crowd every listed row.
- **Pinning listed stations to the top of the spots sheet**: the emoji already makes them easy to find.
- **Editing lists in the app**: a list is just a file at a link; a Gist does the job.
- **Refreshing lists automatically**, even when the Sync tab opens: every other download waits for a tap.

### Activation thresholds

POTA needs 10 QSOs; SOTA needs 4. The activation status shows progress and changes color on completion. This is information, not gatekeeping — the operator can always keep logging.

---

## Speed & Simplicity Checklist

Before proposing any change, run it through these questions:

1. **Does it add a decision point?** If the operator has to choose between options, think, or read instructions — find a way to make the choice for them.

2. **Does it slow the critical path?** Count the taps/keystrokes from "finished a contact" to "ready for the next one." If your change increases that number, it's probably wrong.

3. **Does it require explanation?** If you'd need to add help text, a tooltip, or a label to explain what something does — it's too complex.

4. **Could we make the right choice for the user?** Instead of offering a preference, pick the right default. Instead of asking for confirmation, just do it and make it reversible.

5. **Does it add a screen, modal, or alert?** Every screen transition is friction. Stay on the active log view during the logging flow.

6. **Does it add a network dependency?** The app must work on a mountaintop with no signal. If a feature degrades without network, that's acceptable. If it breaks, it's not.

7. **Does it affect one-handed operation?** The operator might be holding a paddle, a clipboard, or bracing against wind. Touch targets must be reachable and large.

8. **Is it relevant to CW, SSB, or FM operations?** We don't build for hypothetical future modes. If it's not useful for CW, SSB, or FM operations, it doesn't belong.
