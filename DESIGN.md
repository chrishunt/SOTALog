# SOTA Log Design Document

This is the authoritative reference for SOTA Log's design philosophy and intent. Read this before working on any feature or bug. For implementation details, read the code.

---

## Core Philosophy

**Simplicity is the primary feature.** Every decision filters through this. If a change adds complexity, configurability, or cognitive load — it doesn't belong here.

- **One happy path, perfected.** No settings screen. No user-configurable options. We make the right choice so the operator doesn't have to.
- **Elegant, not minimal.** Simple doesn't mean ugly or bare. It means the right information at the right time with zero friction.
- **Instantly usable.** A ham should be able to open this app and start logging without reading a single instruction.
- **CW only.** We don't support SSB, digital modes, or anything else. Mode is always "CW". RST defaults to 599. Don't add mode selectors.
- **Offline-first.** Everything works without internet. All data lives in the local GRDB database. Network operations (QRZ sync, spot fetching, reference downloads) happen only when the user explicitly triggers them.
- **Field-optimized.** Operators use this on summits and in parks, often in cold/wind/rain. Touch targets must be large. Interactions must be minimal. The QSO entry form is the critical path — callsign field auto-focuses, keyboard Send saves from any field, haptic feedback confirms saves.

---

## What NOT to Build

Explicit guardrails — if you're considering any of these, stop and reconsider:

- **Settings or preferences screens.** There's nothing to configure.
- **Mode selectors.** CW only. The mode field is always "CW".
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

1. **Callsign entry** — The callsign field is auto-focused on appear. It's the dominant visual element — big, bold, monospaced. The operator types the callsign they just worked. Additional tokens (RST, frequency, QTH, references) can be space-separated in the same field via the OmniField.

2. **Auto-populate** — Name and QTH fill from history of previous contacts. QTH fills from the callsign prefix if still empty. A "times worked" badge appears for repeat contacts.

3. **Sensible defaults** — Frequency persists from the previous QSO (you're on the same frequency). RST defaults to 599. Band is derived from frequency. Date and time are stamped at save.

4. **Contextual fields** — P2P (park-to-park) row only shows during POTA activations. S2S (summit-to-summit) row only shows during SOTA activations. Don't show fields that aren't relevant.

5. **Save** — Keyboard Send from any field. Haptic fires. Fields clear. Focus returns to callsign. Frequency is preserved. The operator is immediately ready for the next contact.

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

### Field conditions drive sizing

Touch targets must be large enough for cold, gloved, one-handed operation. RST is a tap-to-pick popover, not a keyboard field. List rows are full-width tap targets. The entry panel is pinned at the bottom of the screen, directly above the keyboard, where thumbs naturally rest.

### Haptic as confirmation

A success haptic on save is the only confirmation. No toasts, no banners, no modals. The operator feels it and moves on.

---

## Key Design Decisions

### The OmniField

The callsign field is also a command line. Space-separated tokens after the callsign are parsed as RST, frequency, QTH, or P2P/S2S references. This lets a skilled operator log an entire QSO without leaving a single text field. Unrecognized tokens are silently ignored — never show parse errors in the logging flow.

### Manual overrides are respected

If the operator explicitly edits a field (frequency, QTH, references), the auto-populate and OmniField parser won't overwrite it. This resets after each save. The principle: never fight the operator. Their explicit input always wins.

### Spots feed directly into logging

Tapping a spot switches to the Logs tab, navigates into the active log, and prefills the QSO entry form with the spot's callsign, frequency, and references. One tap from "I see an interesting spot" to "I'm ready to log this contact." Focus lands on callsign.

### Validation is quiet

POTA and SOTA reference inputs validate against the local database. Valid references show a green checkmark and the resolved name. Invalid references show nothing — no error state, just absence of confirmation. Don't punish the operator for typing.

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

8. **Is it CW-specific?** We don't build for hypothetical future modes. If it's not useful for CW operations, it doesn't belong.
