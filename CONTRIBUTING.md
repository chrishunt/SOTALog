# Contributing to SOTA Log

Thanks for your interest in contributing. Please read this guide and [DESIGN.md](DESIGN.md) before submitting a pull request.

## Project Goals

SOTA Log is a field-optimized QSO logger for SOTA and POTA activations. The core philosophy:

- **Simplicity is the primary feature.** Every change must pass through this filter.
- **No settings screen.** The app makes the right choice so the operator doesn't have to.
- **Field-optimized.** Cold hands, wind, rain. Large touch targets. Minimal interactions.
- **Offline-first.** Everything works without internet.
- **CW and SSB only.** No other modes.

Read the full design philosophy in [DESIGN.md](DESIGN.md), especially the "What NOT to Build" and "Speed & Simplicity Checklist" sections.

## What We Won't Accept

- Settings or preferences screens
- New modes beyond CW and SSB
- Complex configuration options
- Features that require explanation or help text
- Decision points in the logging flow
- Automatic background network requests

These aren't negotiable. They're the app's identity.

## Setup

**Prerequisites:**
- Xcode 16+ with iOS 17 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

**Build:**

```sh
cd SOTALog
xcodegen generate
```

Set your own Apple Developer Team ID in `project.yml` under `DEVELOPMENT_TEAM`, then open the generated project in Xcode or build from the command line:

```sh
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build \
  build
```

**Run tests:**

```sh
swift test
```

All tests should pass. Run tests before submitting any PR.

## Submitting a Pull Request

1. **Read [DESIGN.md](DESIGN.md)** — understand the design philosophy before writing code
2. **Keep changes small and focused** — one concern per PR
3. **Run tests** — `swift test` from `SOTALog/`
4. **Match existing style** — follow the patterns you see in the codebase
5. **No new dependencies** without discussion — the app has one external dependency (GRDB) and we'd like to keep it that way

## Working with AI

AI coding tools are encouraged. Be thoughtful of the person reviewing your PR:

- **Keep PRs small and focused.** Don't let AI generate sprawling changes that are painful to review.
- **Understand every line you submit.** If you can't explain why a change exists, don't submit it.
- **Read [DESIGN.md](DESIGN.md) first** — it's written as a guardrail document that works for both humans and AI agents. Feed it to your AI tool as context.
- **[CLAUDE.md](CLAUDE.md)** has build, test, and deploy instructions formatted for AI coding agents.
- **Don't reference AI tools** in commits or code.
