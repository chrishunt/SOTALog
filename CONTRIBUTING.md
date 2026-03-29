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

**Build (iOS):**

```sh
cd ios
xcodegen generate
```

Set your own Apple Developer Team ID in `ios/project.yml` under `DEVELOPMENT_TEAM`, then open the generated project in Xcode or build from the command line:

```sh
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build \
  build
```

**Build (Android):**

```sh
cd android
./gradlew assembleDebug
```

**Run tests:**

```sh
cd ios && swift test          # iOS
cd android && ./gradlew testDebugUnitTest  # Android
```

All tests should pass on both platforms. Run tests before submitting any PR.

## Mock SOTACat Server

To test SOTACat integration from the iOS Simulator, run the mock server which impersonates a SOTACat device via Bonjour:

```sh
sudo python3 tools/mock_sotacat.py
```

Requires `sudo` because the real SOTACat serves on port 80. The app discovers `sotacat.local` within ~5 seconds. The console logs all radio commands and CW keyer messages.

**Interactive console commands:**

| Command | Description |
|---------|-------------|
| `f <hz>` | Set frequency (e.g. `f 7030000`) |
| `m <mode>` | Set mode (e.g. `m SSB`) |
| `w <wpm>` | Set CW speed (0 = no delay) |
| `q` | Quit |

**Run mock server tests** (no sudo needed):

```sh
python3 -m pytest tools/test_mock_sotacat.py -v
```

## Submitting a Pull Request

1. **Read [DESIGN.md](DESIGN.md)** — understand the design philosophy before writing code
2. **Keep changes small and focused** — one concern per PR
3. **Run tests** — `swift test` from `ios/` (and `./gradlew testDebugUnitTest` from `android/`)
4. **Match existing style** — follow the patterns you see in the codebase
5. **No new dependencies** without discussion — the app has one external dependency (GRDB) and we'd like to keep it that way

## Working with AI

AI coding tools are encouraged. Be thoughtful of the person reviewing your PR:

- **Keep PRs small and focused.** Don't let AI generate sprawling changes that are painful to review.
- **Understand every line you submit.** If you can't explain why a change exists, don't submit it.
- **Read [DESIGN.md](DESIGN.md) first** — it's written as a guardrail document that works for both humans and AI agents. Feed it to your AI tool as context.
- **[CLAUDE.md](CLAUDE.md)** has cross-platform workflow instructions. **[ios/CLAUDE.md](ios/CLAUDE.md)** and **[android/CLAUDE.md](android/CLAUDE.md)** have platform-specific build and deploy instructions.
- **Don't reference AI tools** in commits or code.
