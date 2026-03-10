# SOTA Log

A field-optimized QSO logger for [SOTA](https://www.sota.org.uk) and [POTA](https://pota.app) activations on iOS.

Built for summits and parks — cold hands, wind, rain. One text field. One tap to save. No settings.

## OmniField Entry

Log a contact in a single line. Type space-separated tokens and they're automatically parsed:

```
W1AW 59 14.060 CA US4431
```

The app recognizes callsigns, RST, frequencies, modes, QTH (US states/provinces), POTA parks, and SOTA summits — then routes each token to the right field. Unrecognized input is silently ignored. Keyboard Send saves from any field.

## SOTACat Radio Control

Auto-discovers your [SOTACat](https://sotacat.com) via Bonjour. Once connected:

- **VFO sync** — frequency and mode flow between app and radio
- **Spot pouncing** — tap a spot to tune your radio directly
- **CW keyer** — six programmable macro buttons send CW through your radio with template variables (`{call}`, `{myCall}`, `{rst}`, `{mySOTA}`)

## Live Spots

Pull SOTA and POTA spots into a half-sheet overlay. Filter by program and mode. Each spot shows activator, frequency, reference name, and age. Tap any spot to prefill your QSO form and tune your radio. Worked stations are marked.

## Smart Defaults

- **Mode auto-derives from frequency** — CW sub-band vs SSB sub-band
- **RST defaults match mode** — 599 for CW, 59 for SSB
- **Frequency persists** between contacts
- **Name and QTH auto-populate** from contact history
- **Dupe detection** per callsign+band (mode-aware)
- **Activation progress** tracks QSO count toward thresholds (SOTA: 4, POTA: 10)

## QRZ Integration

Look up callsign info (name, QTH, grid) from QRZ. Sync your log to QRZ Logbook with a 3-tier merge strategy. ADIF import/export with program-specific fields.

## Offline-First

All data lives in a local SQLite database (GRDB). Every feature works without internet. Network operations — QRZ sync, spot fetching, reference downloads — happen only when you trigger them.

## Design Principles

- **No settings screen.** The app makes the right choice.
- **No modals in the logging flow.** Type, send, repeat.
- **Large touch targets.** Gloves-friendly.
- **Haptic feedback on save.** The only confirmation you need.
- **Dark theme with semantic colors.** Orange = editing, green = POTA, blue = SOTA.
- **Colorblind-safe palette.**

## Technical Details

- SwiftUI + iOS 17+
- GRDB (SQLite) for local persistence
- Bonjour for SOTACat discovery
- Portrait-only, iPhone-optimized
- TestFlight distribution

## Website

The support page at [sotalog.k2mmt.com](https://sotalog.k2mmt.com) is hosted on Cloudflare Workers.

Deploy from the command line:

```sh
npx wrangler deploy
```

## Development

### Mock SOTACat Server

Test SOTACat integration from the iOS Simulator using the mock server, which impersonates a SOTACat device via Bonjour:

```sh
sudo python3 tools/mock_sotacat.py
```

Requires `sudo` (binds to port 80). Python 3 standard library only — no extra dependencies.

The app discovers `sotacat.local` within ~5 seconds. Interactive console commands:

- `f <hz>` — set frequency (e.g. `f 7030000`)
- `m <mode>` — set mode (e.g. `m SSB`)
- `w <wpm>` — set CW speed
- `q` — quit
