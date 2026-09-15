# iOS Agent Guide

> **Read [../DESIGN.md](../DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Build & Run

### Quick compile check (macOS target)

```sh
cd ios && swift build
```

### HamCore

The domain layer — models, the database, ADIF, band plan, OmniField parsing, and the SOTA, POTA and QRZ clients — is the [`ham-core`](https://github.com/chrishunt/ham-core) package, pinned by version in `Package.swift` and `project.yml`. Its own repository documents how it works (a DocC catalog and `Documentation/`); this one documents only how the app uses it:

- `App/LogbookDatabase+App.swift` opens the database in Application Support and puts it in the SwiftUI environment as `appDatabase`.
- `App/SOTALogIdentity.swift` is the app's name and version as HamCore sees them: `APIClient.sotaLog` carries the User-Agent to SOTA, POTA and QRZ, and `ADIFFormatter.Software.sotaLog` goes into ADIF headers.
- `Services/KeychainService.swift` and `Services/KeychainQRZCredentials.swift` keep QRZ credentials in the keychain and hand them to HamCore's QRZ lookup through its `QRZCredentialStore` protocol.
- `Services/ADIFFile+Transferable.swift` makes HamCore's ADIF documents shareable and declares the `.adi` type from Info.plist.
- `Models/CWMacro+Defaults.swift` holds the six default message keys; HamCore stores macros but not their content, so the app seeds them on first use.
- `SOTALogTests/HamCoreBoundaryTests.swift` checks these seams. Tests never touch the network; HamCore's clients take an injectable transport if a test ever needs one.

Domain logic belongs in ham-core, not here. To change both at once, point the iOS package at a local checkout while you work, then put the pin back:

```sh
swift package edit ham-core --path ../../ham-core   # from ios/
swift package unedit ham-core                        # when done
```

Run ham-core's own `swift test` in that repo for any change made there, and bump the pin here once it is tagged.

### iOS Simulator build, install, and launch

All commands below run from `ios/` (the subdirectory containing the Xcode project and `project.yml`).

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
- **Derived data**: `-derivedDataPath build` puts output in `build/` relative to `ios/`
- **App bundle path**: `build/Build/Products/Debug-iphonesimulator/SOTALog.app` (relative to `ios/`)

### SOTACat mock server (simulator testing)

To test SOTACat integration from the simulator, run the mock server which impersonates a SOTACat device via Bonjour:

```sh
sudo python3 ../tools/mock_sotacat.py
```

The app discovers `sotacat.local` within ~5 seconds. The console shows all radio commands and CW keyer messages. Type `f <hz>` or `m <mode>` to simulate VFO changes, `q` to quit.

Run mock server tests (no sudo needed):
```sh
python3 -m pytest ../tools/test_mock_sotacat.py -v
```

### TestFlight deployment

Versioning is in `project.yml` under the SOTALog target settings:
- `MARKETING_VERSION` — user-facing version (e.g. `"1.3"`)
- `CURRENT_PROJECT_VERSION` — build number, must increment for each upload

Bump the build number before each upload:
```yaml
CURRENT_PROJECT_VERSION: 16   # was 15
```

Then regenerate and archive (run from `ios/`):
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
- **Team ID**: Set `DEVELOPMENT_TEAM` in `project.yml` to your own Apple Developer Team ID
- **Bundle ID**: `com.sotalog.app`
- **Signing**: Automatic (Apple Development certificate)

### Release checklist

**Pre-release:**

1. Review changes since last tag: `git log <last-tag>..HEAD --oneline`
2. Update `CHANGELOG.md` (at repo root) — add any missing entries to Unreleased, then move Unreleased items under a dated version heading (e.g. `## [1.4] - 2026-04-01`). Follow [Keep a Changelog](https://keepachangelog.com/) format.
3. Choose version number — MAJOR.MINOR style. Bump MINOR for features, MAJOR for breaking changes or milestones.
4. Update `VERSION` file at repo root
5. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`

**Test & verify:**

6. Run tests: `swift test` (from `ios/`)
7. Build for the simulator, install, and launch to verify the app works (follow "iOS Simulator build, install, and launch" steps above)

**Build & upload:**

8. Regenerate and archive (run from `ios/`):
```sh
xcodegen generate
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphoneos -configuration Release \
  -archivePath build/SOTALog.xcarchive \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  archive
```
9. Open archive in Xcode Organizer (`open build/SOTALog.xcarchive`), then **Distribute App → TestFlight & App Store → Upload**

**Post-upload:**

10. Commit version bump + changelog on a release branch (`git commit -m "Release <version>"`), open a PR against `main`, and merge it once CI passes. `main` does not accept direct pushes.
11. Tag the merge commit on `main`: `git fetch origin && git tag v<version> origin/main`, then push with `git push origin v<version>`
12. Update comparison links at the bottom of `CHANGELOG.md` to include the new version
13. In App Store Connect, add "What to Test" notes from the changelog
14. Verify build appears in TestFlight for beta testers

**App Store release:**

15. In App Store Connect: **Apps → SOTA Log → App Store → + (new version) → enter version number**
16. Select the uploaded build under **Build**
17. Print the **"What's New in This Version"** summary for the user to paste. Format: no bullets, short plain-English lines (one per feature/fix), no markdown. Derive from the changelog entries for this version.
18. Update **Version** field to match the new version number
19. **Add for Review → Submit to App Review**

## Workflow

- After completing a change, always run tests first (`swift test` from `ios/`). If tests pass, build for the simulator, install, and launch the app so the user can test. Follow the "iOS Simulator build, install, and launch" steps above.
