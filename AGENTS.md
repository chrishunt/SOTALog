# DitLog Design Principles

## Core Philosophy

**Simplicity is the primary feature.** Every decision filters through this. If a change adds complexity, configurability, or cognitive load — it doesn't belong here.

- **One happy path, perfected.** No settings screen. No user-configurable options. We make the right choice so the operator doesn't have to.
- **Elegant, not minimal.** Simple doesn't mean ugly or bare. It means the right information at the right time with zero friction.
- **Instantly usable.** A ham should be able to open this app and start logging without reading a single instruction.
- **CW only.** We don't support SSB, digital modes, or anything else. Mode is always "CW". RST defaults to 599. Don't add mode selectors.
- **Offline-first.** Everything works without internet. All data lives in the local GRDB database. Network operations (QRZ sync, spot fetching, reference downloads) happen only when the user explicitly triggers them.
- **Field-optimized.** Operators use this on summits and in parks, often in cold/wind/rain. Touch targets must be large. Interactions must be minimal. The QSO entry form is the critical path — callsign field auto-focuses, LOG button is full-width, haptic feedback confirms saves.

## What NOT to Add

- Settings/preferences screens
- Mode selectors (CW only)
- Complex configuration options
- Features that require explanation
- Automatic background network requests
- Anything that adds a decision point to the logging flow

## Architecture

- **SwiftUI + @Observable** (Swift 5.9 Observation, not ObservableObject)
- **GRDB.swift v7** for local persistence, observation via `start(in:onChange:)` pattern
- **3 tabs**: Logs (list activations), Spots (live CW spots from POTA/SOTA), Sync (QRZ upload/download, ADIF export, reference DB management)
- **Repositories pattern** for all database access (LogRepository, QSORepository, etc.)
- **AppDatabase** injected via SwiftUI Environment
- **XcodeGen** (`project.yml`) generates the Xcode project; also has `Package.swift` for SPM/macOS builds
- Platform shims in `Extensions/View+iOS.swift` for cross-platform compilation

## Data Model

- **Log**: An activation session (callsign, date, grid, optional POTA/SOTA reference). A log contains QSOs.
- **QSO**: A single contact (callsign, time, frequency, band, RST, optional name/QTH/grid/SOTA ref/POTA ref).
- POTA activations need 10 QSOs; SOTA needs 4. The ThresholdBadge shows progress.

## Critical Path: Logging a QSO

The most important flow in the app. Protect its speed and simplicity above all:

1. Operator enters callsign (auto-capitalized, monospaced, 44pt)
2. Frequency, RST default to sensible values; name/QTH auto-populated from history
3. If POTA/SOTA activation: P2P/S2S fields appear for park-to-park or summit-to-summit
4. Tap LOG QSO — haptic fires, callsign clears, focus returns to callsign field
5. New QSO appears in the list below

## Build & Run

- `swift build` for compile-check (macOS target)
- Xcode build for iOS simulator: use `iPhone 17 Pro`
- Xcode at `/Applications/Xcode.app`

## Commit Standards

- Short subject lines following standard git conventions
- Never reference AI tools in commits, code, or anywhere in the codebase
