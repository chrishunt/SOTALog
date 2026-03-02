# Changelog

All notable changes to SOTA Log will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

[unreleased]: https://github.com/chrishunt/Field-Log/compare/v0.2...HEAD
[0.2]: https://github.com/chrishunt/Field-Log/compare/v0.1...v0.2
[0.1]: https://github.com/chrishunt/Field-Log/releases/tag/v0.1
