<p align="center">
  <img src="docs/app-icon.png" width="128" height="128" alt="SOTA Log">
</p>

<h1 align="center">SOTA Log</h1>

<p align="center">
  Log a QSO in seconds. Field logger for SOTA and POTA activations on iOS.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/sota-log/id6759876471">
    <img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1736380800" alt="Download on the App Store" height="44">
  </a>
</p>

---

Built for summits and parks — cold hands, wind, rain. One text field. One tap to save. No settings. The app makes the right choice so you don't have to.

## Features

**OmniField entry** — Log a contact in a single line. Type space-separated tokens and they're automatically parsed: `W1AW 59 14.060 CA US4431`. Callsigns, RST, frequencies, modes, QTH, park and summit references all route to the right field.

**SOTACat radio control** — Auto-discovers your [SOTACat](https://sotamat.com/sotacat/) via Bonjour. VFO sync, spot pouncing, and six programmable CW macro buttons with template variables.

**Live spots** — Pull SOTA and POTA spots into a half-sheet overlay. Filter by program and mode. Tap a spot to prefill your QSO and tune your radio.

**Smart defaults** — Mode derives from frequency. RST defaults match mode. Frequency persists between contacts. Name and QTH auto-populate from history. Dupe detection per callsign+band.

**QRZ sync** — Look up callsign info. Sync your log to QRZ Logbook. ADIF import/export.

**Offline-first** — All data lives in a local SQLite database. Every feature works without internet. Network operations happen only when you trigger them.

## Design Philosophy

- **One happy path, perfected.** No settings screen. No user-configurable options.
- **Elegant, not minimal.** The right information at the right time with zero friction.
- **Field-optimized.** Large touch targets. Haptic confirmation. Keyboard Send saves from any field.
- **CW and SSB.** Mode auto-derives from frequency. No other modes.

Read the full design philosophy in [DESIGN.md](DESIGN.md).

## Building from Source

**Prerequisites:** Xcode 16+, iOS 17 SDK, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```sh
cd SOTALog
xcodegen generate
swift test
```

Set your `DEVELOPMENT_TEAM` in `project.yml`, then build in Xcode or from the command line. See [CLAUDE.md](CLAUDE.md) for detailed build, simulator, and deployment instructions.

## Working with AI

AI coding tools are encouraged. Be thoughtful of the person reviewing your PR.

- **Keep PRs small and focused.** Don't let AI generate sprawling changes that are painful to review.
- **Understand every line you submit.** If you can't explain why a change exists, don't submit it.
- **Read [DESIGN.md](DESIGN.md) first** — it's written as a guardrail document that works for both humans and AI agents.
- **[CLAUDE.md](CLAUDE.md)** has build, test, and deploy instructions for AI coding agents.
- Don't reference AI tools in commits or code.

## Contributing

Read the [contributing guide](CONTRIBUTING.md) and [DESIGN.md](DESIGN.md) before submitting a pull request.

## Website

The support page at [sotalog.k2mmt.com](https://sotalog.k2mmt.com) is hosted on Cloudflare Workers. Deploy: `npx wrangler deploy`

## License

[MIT](LICENSE)
