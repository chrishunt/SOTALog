# SOTA Log Agent Guide

> **Read [DESIGN.md](DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Build & Run

### Quick compile check (macOS target)

```sh
cd SOTALog && swift build
```

### iOS Simulator build, install, and launch

All commands below run from `SOTALog/` (the subdirectory containing the Xcode project and `project.yml`).

The Xcode project is generated via XcodeGen. Regenerate before building if project.yml or file structure changed:

```sh
xcodegen generate
```

Look up the simulator device ID (the UUID varies per machine):

```sh
DEVICE=$(xcrun simctl list devices available | grep "iPhone 17 Pro" | head -1 | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
```

Build for the simulator:

```sh
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build \
  build
```

Boot the simulator, open the Simulator app, install, and launch:

```sh
xcrun simctl boot "$DEVICE" 2>/dev/null || true   # no-op if already booted
open -a Simulator                                  # bring window to front

xcrun simctl install "$DEVICE" \
  build/Build/Products/Debug-iphonesimulator/SOTALog.app

xcrun simctl launch "$DEVICE" com.sotalog.app
```

Key details:
- **Simulator**: iPhone 17 Pro (look up device UUID dynamically — it varies per machine)
- **Bundle ID**: `com.sotalog.app` (not `com.huntca.SOTALog`)
- **Derived data**: `-derivedDataPath build` puts output in `build/` relative to `SOTALog/`
- **App bundle path**: `build/Build/Products/Debug-iphonesimulator/SOTALog.app` (relative to `SOTALog/`)

### TestFlight deployment

Versioning is in `project.yml` under the SOTALog target settings:
- `MARKETING_VERSION` — user-facing version (e.g. `"0.1"`)
- `CURRENT_PROJECT_VERSION` — build number, must increment for each upload

Bump the build number before each upload:
```yaml
CURRENT_PROJECT_VERSION: 2   # was 1
```

Then regenerate and archive (run from `SOTALog/`):
```sh
xcodegen generate
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphoneos -configuration Release \
  -archivePath build/SOTALog.xcarchive \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  archive
```

Upload via Xcode Organizer:
```sh
open build/SOTALog.xcarchive   # opens in Organizer
```
Then: **Distribute App → TestFlight & App Store → Upload**.

Key details:
- **Team ID**: `8CV6QZZ6BE`
- **Bundle ID**: `com.sotalog.app`
- **Signing**: Automatic (Apple Development certificate)

### Release checklist

**Pre-release:**

1. Review changes since last tag: `git log <last-tag>..HEAD --oneline`
2. Update `CHANGELOG.md` — add any missing entries to Unreleased, then move Unreleased items under a dated version heading (e.g. `## [0.3] - 2026-04-01`). Follow [Keep a Changelog](https://keepachangelog.com/) format.
3. Choose version number — MAJOR.MINOR style. Bump MINOR for features, MAJOR for breaking changes or milestones.
4. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`

**Build & upload:**

5. Regenerate and archive (run from `SOTALog/`):
```sh
xcodegen generate
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphoneos -configuration Release \
  -archivePath build/SOTALog.xcarchive \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  archive
```
6. Open archive in Xcode Organizer (`open build/SOTALog.xcarchive`), then **Distribute App → TestFlight & App Store → Upload**

**Post-upload:**

7. Commit version bump + changelog: `git commit -m "Release <version>"`
8. Tag: `git tag v<version>` and push with `git push --tags`
9. Update comparison links at the bottom of `CHANGELOG.md` to include the new version
10. In App Store Connect, add "What to Test" notes from the changelog
11. Verify build appears in TestFlight for beta testers

## Workflow

- After completing a change, always run tests first (`swift test` from `SOTALog/`). If tests pass, build for the simulator, install, and launch the app so the user can test. Follow the "iOS Simulator build, install, and launch" steps above.

## Commit Standards

- Short subject lines following standard git conventions
- Never reference AI tools in commits, code, or anywhere in the codebase
