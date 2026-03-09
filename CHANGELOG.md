# Changelog

All notable changes to SOTA Log will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0] - 2026-03-09

### Changed
- Public App Store release

## [0.11] - 2026-03-04

### Fixed
- Export ADIF files with proper .adi type

## [0.10] - 2026-03-04

### Changed
- Added spots onboarding tip and clarified QRZ labels

## [0.9] - 2026-03-04

### Added
- CW macro length indicator showing character count
- 24-character CW macro limit enforced in UI

### Fixed
- CW keyer encoding for reliable message transmission
- Reduced false SOTACat disconnects on transient network errors

## [0.8] - 2026-03-04

### Added
- Omnibox onboarding tip for new users
- QRZ badge on fully-synced logs
- CW keyer blocking simulation in mock server

### Changed
- Renamed Settings tab to Sync
- Updated default CW macros
- Disable empty CW macros instead of hiding them
- Improved SOTACat radio sync and CW keyer

### Fixed
- Mode push and macros disabled during send to prevent conflicts
- Log row layout alignment

## [0.7] - 2026-03-04

### Added
- Privacy manifest declaring UserDefaults API usage
- Local network usage description for SOTACat discovery

### Changed
- Locked interface orientation to portrait only
- Split toolbar into separate ToolbarItems
- Handle database initialization failure gracefully instead of crashing

## [0.6] - 2026-03-04

### Changed
- Moved spots from tab to ActiveLogView sheet
- Renamed Tools tab to Settings
- Large navigation titles on main tabs
- Increased small font tokens from caption to footnote
- Extracted shared design tokens and components
- Limited metadata strip line 1 to single line

## [0.5] - 2026-03-04

### Added
- CW macro buttons with SOTACat keyer for sending CW messages during QSOs
- Nearby reference suggestions for activations
- SSB mode support with auto-derivation from frequency (CW sub-band vs SSB sub-band)
- Mode toggle in metadata strip (tap to switch CW↔SSB)
- Mode token recognition in OmniField parser (type "CW" or "SSB")
- Mode-aware RST defaults (599 for CW, 59 for SSB)
- Mode-aware dupe detection (CW and SSB on the same band are separate contacts)
- Mode display in QSO row and spot row band badges ("20M CW", "40M SSB")
- SSB spots from SOTA and POTA spot services
- BandPlan SSB boundary frequencies and default SSB frequencies
- Mode filter on logs list
- ADIF export with program-specific filtering
- SOTACat mock server for simulator testing
- Cut numbers in CW messages

### Changed
- Sync frequency and mode to radio via SOTACat
- Moved radio indicator to frequency display and improved macro layout
- Restyled CW macro buttons and metadata strip buttons with pill backgrounds
- Mountain icon for Activations tab
- Renamed app display name to "SOTA Log"
- Updated app icon and QRZ sync badge
- Renamed Logs tab

### Removed
- RSTField popover component (unused)

### Fixed
- Thread safety: Mark NewLogViewModel as @MainActor

## [0.4] - 2026-03-03

### Added
- SOTACat radio integration with auto-discovery, VFO frequency sync, and spot pouncing
- SOTA Database API with epoch-based polling and CW-filtered spots
- Inline reference data download prompts in new log view
- Reusable ReferenceDownloadRow component
- 2m band (144–148 MHz) to band plan
- Cascade-delete unsynced QSOs when removing a log

### Changed
- Migrated spot service to SOTA DB2 API with independent SOTA/POTA spot storage
- Show park/summit names in log rows below reference badges
- Spot rows show age instead of full timestamp, band badge moved to reference row
- ADIF band parsing prefers frequency-derived band over raw BAND field

## [0.3] - 2026-03-02

### Added
- Activation progress tracking with worked spot indicators
- Metadata strip showing token consumption
- Semantic color tokens for dark theme
- Icons and themed colors in park/summit search results

### Changed
- Two-line layout for QSO log rows with capsule band badges
- Frequency shown first in metadata strip
- Unified data display across all views
- Park and summit reference fields always visible
- Number keys moved from toolbar to inline row
- Replaced incremental sync with full-refresh import

## [0.2] - 2026-03-02

### Added
- Cross-log QSO search by callsign
- Colorblind-safe color palette
- QRZ lookup extracted as standalone service with parallel resolution
- Dupe detection for callsign+band per log
- Worked-today count in callsign badge
- Log context to ADIF export

### Changed
- Display QRZ nickname when available instead of first/last name
- Simplified QRZ credentials page labels
- QSO entry polish
- Pin entry form above keyboard, remove LOG button
- Disable autofill on entry fields, fix keyboard toolbar
- Rewrite QRZ sync with 3-tier merge strategy

### Fixed
- ADIF export override handling
- QRZ sync encoding and batch import pipeline
- QRZ sync accuracy and inline status display

## [0.1] - 2026-03-01

### Added
- Single-line QSO entry with omnifield
- Spot browser with POTA spot integration
- Spot-to-log routing (tap a spot to start a QSO)
- Auto-populated references from spot data
- QRZ callsign lookup
- ADIF import/export
- Frequency-to-band mapping
- Callsign prefix to QTH resolution
- Maidenhead grid square conversion
- TestFlight distribution configuration

[unreleased]: https://github.com/chrishunt/Field-Log/compare/v1.0...HEAD
[1.0]: https://github.com/chrishunt/Field-Log/compare/v0.11...v1.0
[0.11]: https://github.com/chrishunt/Field-Log/compare/v0.10...v0.11
[0.10]: https://github.com/chrishunt/Field-Log/compare/v0.9...v0.10
[0.9]: https://github.com/chrishunt/Field-Log/compare/v0.8...v0.9
[0.8]: https://github.com/chrishunt/Field-Log/compare/v0.7...v0.8
[0.7]: https://github.com/chrishunt/Field-Log/compare/v0.6...v0.7
[0.6]: https://github.com/chrishunt/Field-Log/compare/v0.5...v0.6
[0.5]: https://github.com/chrishunt/Field-Log/compare/v0.4...v0.5
[0.4]: https://github.com/chrishunt/Field-Log/compare/v0.3...v0.4
[0.3]: https://github.com/chrishunt/Field-Log/compare/v0.2...v0.3
[0.2]: https://github.com/chrishunt/Field-Log/compare/v0.1...v0.2
[0.1]: https://github.com/chrishunt/Field-Log/releases/tag/v0.1
