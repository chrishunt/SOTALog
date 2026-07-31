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

---

## The Critical Path: Logging a QSO

This is the most important flow in the app. Protect its speed and simplicity above all else.

### Why every detail matters

The operator is sitting on a cold summit or crouched at a picnic table in a park. They're copying Morse code by ear at 20+ WPM. They have maybe 2 seconds between finishing a contact and calling the next station. The app must be an extension of their muscle memory, not a distraction.

### The flow

1. **Callsign entry** — The callsign field is auto-focused on appear. It's the dominant visual element — big, bold, monospaced. The operator types the callsign they just worked. Additional tokens (RST, frequency, QTH, references) can be space-separated in the same field via the OmniField. The placeholder shows a realistic example (`W1AW 59 59 CA W6SD133`) so operators discover the OmniField's capabilities.

2. **Auto-populate** — Name and QTH fill from history of previous contacts. QTH fills from the callsign prefix if still empty. A "times worked" badge appears for repeat contacts.

3. **Sensible defaults** — Frequency persists from the previous QSO (you're on the same frequency). Mode is derived from frequency (CW, SSB, or FM sub-band). RST defaults to 599 for CW, 59 for voice modes. Band is derived from frequency. Date and time are stamped at save.

4. **Metadata strip** — All QSO metadata lives in a compact chip cloud above the callsign, in stable semantic order: time (when set), frequency, mode, RST sent, RST received, park/summit references with validation checkmarks, then name, QTH, and grid as they populate. Chips keep their natural size and wrap to more rows when they don't fit — data chips never truncate, never reorder; prose (the name) is width-capped instead. Tap any chip to edit it inline. This replaces separate field rows — one component, uniform interaction.

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

**Token consumption:** When the parser recognizes a token (frequency, QTH, grid, time, park ref, summit ref) and the operator types a space after it, the token is consumed — stripped from the callsign field and "moved" to the metadata strip. The callsign and RST tokens always remain in the field. This keeps the omnibox clean: type `W1AW 59 55 14.060 NC ` and the field shows `W1AW 59 55` while the metadata strip displays the consumed values.

### Manual overrides are respected

If the operator explicitly provides a value — whether by editing a field directly or via the OmniField — auto-populate won't overwrite it. This resets after each save. The principle: never fight the operator. The most recent explicit input always wins.

### Time is stamped, not asked — but always correctable

New QSOs stamp date and time at save; time is never a decision point in the logging flow. For contacts logged after the fact, the operator can back-time at entry with a time token (`1432Z`) or fix it later: tap the QSO row to edit, then tap the time chip that appears first on the metadata strip. The chip only exists when it has a value (editing, or a typed token), so the entry panel stays clean during live logging. Invalid time input quietly reverts — same rule as reference validation. The QSO list orders by QSO time, not entry order, so a corrected time visibly moves the row to its chronological place. Dates are not editable in-app; that edge case (crossing UTC midnight) is left to the program websites.

### Spots feed directly into logging

Spots live in a half-sheet accessible from ActiveLogView's toolbar (antenna icon). The sheet starts at half-height (`.medium` detent) and expands to full. Tapping a spot dismisses the sheet and prefills the QSO entry form with the spot's callsign, frequency, and references. The round-trip is two taps: antenna button → tap spot → log → repeat. There is no dedicated Spots tab — viewing spots without a log open is useless.

### Validation is quiet

POTA and SOTA reference inputs validate against the local database. Valid references show a checkmark in their type color (green for POTA, blue for SOTA) and the resolved name. Invalid references show nothing — no error state, just absence of confirmation. Don't punish the operator for typing.

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
