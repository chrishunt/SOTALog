# SOTA Log Agent Guide

> **Read [DESIGN.md](DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Repository Structure

- **`ios/`** — the Swift/SwiftUI iOS app ([iOS build & deploy instructions](ios/CLAUDE.md))

The app's domain layer — models, the GRDB logbook and reference database with its migrations, ADIF, band plan, callsign utilities, and the SOTA, POTA and QRZ clients — is the separate [`ham-core`](https://github.com/chrishunt/ham-core) package (module `HamCore`), pinned in `ios/Package.swift` and `ios/project.yml`. Domain code goes there; app-specific code (views, view models, SOTACat, SOTAmat, location) stays here.

Documentation at the root: `DESIGN.md`, `CHANGELOG.md`, `VERSION`.

## Version Management

The `VERSION` file at the repo root is the app version (e.g. `1.3`). `MARKETING_VERSION` in `ios/project.yml` must match it.

## Commit Standards

- Short subject lines following standard git conventions
- Never reference AI tools in commits, code, or anywhere in the codebase
