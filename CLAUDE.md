# SOTA Log Agent Guide

> **Read [DESIGN.md](DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Build & Run

### Quick compile check (macOS target)

```sh
cd SOTALog && swift build
```

### iOS Simulator build, install, and launch

The Xcode project is generated via XcodeGen. Regenerate before building if project.yml or file structure changed:

```sh
xcodegen generate   # from repo root — creates SOTALog/SOTALog.xcodeproj
```

Build for the simulator (run from `SOTALog/`):

```sh
xcodebuild -project SOTALog.xcodeproj -scheme SOTALog \
  -sdk iphonesimulator \
  -destination 'id=F16D6510-431D-4274-8C97-206C2EAA6359' \
  -derivedDataPath build \
  build
```

Install and launch:

```sh
xcrun simctl install F16D6510-431D-4274-8C97-206C2EAA6359 \
  SOTALog/build/Build/Products/Debug-iphonesimulator/SOTALog.app

xcrun simctl launch F16D6510-431D-4274-8C97-206C2EAA6359 com.sotalog.app
```

Key details:
- **Simulator**: iPhone 17 Pro (`F16D6510-431D-4274-8C97-206C2EAA6359`)
- **Bundle ID**: `com.sotalog.app` (not `com.huntca.SOTALog`)
- **Derived data**: `-derivedDataPath build` puts output in `SOTALog/build/` (paths are relative to where xcodebuild runs)
- **App bundle path**: `SOTALog/build/Build/Products/Debug-iphonesimulator/SOTALog.app`

## Commit Standards

- Short subject lines following standard git conventions
- Never reference AI tools in commits, code, or anywhere in the codebase
