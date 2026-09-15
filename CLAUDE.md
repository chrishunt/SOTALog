# SOTA Log Agent Guide

> **Read [DESIGN.md](DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Repository Structure

This monorepo contains two independent native apps:

- **`ios/`** — Swift/SwiftUI iOS app ([iOS build & deploy instructions](ios/CLAUDE.md))
- **`android/`** — Kotlin/Jetpack Compose Android app ([Android build & deploy instructions](android/CLAUDE.md))

The iOS app's domain layer — models, the GRDB logbook and reference database with its migrations, ADIF, band plan, callsign utilities, and the SOTA, POTA and QRZ clients — is the separate [`ham-core`](https://github.com/chrishunt/ham-core) package (module `HamCore`), pinned in `ios/Package.swift` and `ios/project.yml`. Domain code goes there; app-specific code (views, view models, SOTACat, SOTAmat, location) stays here.

Shared documentation at the root (`DESIGN.md`, `CHANGELOG.md`, `VERSION`) keeps both platforms aligned. The Android app shares no compiled code with iOS — it is fully native and self-contained.

## Version Management

The `VERSION` file at the repo root is the single source of truth for the app version (e.g. `1.3`). Both platforms read from this file:

- **iOS**: `MARKETING_VERSION` in `ios/project.yml` must match `VERSION`
- **Android**: `build.gradle.kts` reads `VERSION` for `versionName`

Build numbers are managed independently per platform.

## Commit Standards

- Short subject lines following standard git conventions
- Never reference AI tools in commits, code, or anywhere in the codebase

## Cross-Platform Feature Porting

When asked to port iOS changes to Android:

1. **Read the iOS changes**: Check `git log` and `git diff` in `ios/` (and in ham-core, if the pin moved) to understand what changed. Read the modified iOS source files completely.

2. **Identify the layers affected** and map to Android locations:

   | iOS Layer | iOS Location | Android Location | Translation |
   |-----------|-------------|-----------------|-------------|
   | Models | ham-core `Sources/HamCore/Models/` | `android/.../domain/models/` | struct → data class |
   | Pure Services | ham-core `Sources/HamCore/Services/` | `android/.../domain/services/` | static enum → object |
   | DB Repos | ham-core `Sources/HamCore/Database/` | `android/.../data/repositories/` | GRDB → Room DAO + Repository |
   | DB Migrations | ham-core `Sources/HamCore/Database/AppDatabase.swift` | `android/.../data/local/database/migration/` | GRDB migration → Room Migration |
   | Network | ham-core `Sources/HamCore/Network/` (SOTACat: `ios/SOTALog/Services/Network/`) | `android/.../data/remote/api/` | URLSession → Retrofit |
   | ViewModels | `ios/SOTALog/ViewModels/` | `android/.../ui/<feature>/` | @Observable → ViewModel + StateFlow |
   | Views | `ios/SOTALog/Views/` | `android/.../ui/<feature>/` | SwiftUI → @Composable |
   | Tests | ham-core `Tests/HamCoreTests/`, `ios/SOTALogTests/` | `android/app/src/test/` | XCTest → JUnit5 + MockK |

3. **Port each layer** following the mapping above. Key translation patterns:
   - Swift struct → Kotlin data class
   - Swift enum → Kotlin sealed class or enum class
   - Swift `@Observable` class → Kotlin ViewModel with StateFlow
   - SwiftUI `View` → `@Composable` function
   - GRDB query → Room `@Query` annotation
   - URLSession call → Retrofit interface method
   - Swift `async`/`await` → Kotlin `suspend` function
   - Swift extension → Kotlin extension function
   - `@Published` / `@State` → `MutableStateFlow` / `collectAsStateWithLifecycle()`

4. **Port tests**: Every iOS test should have an Android equivalent.
   - `XCTestCase` → JUnit5 `@Test`
   - `XCTAssertEqual` → `assertEquals`
   - Swift async test → `runTest { }`
   - In-memory GRDB → In-memory Room database

5. **Run Android tests**: `cd android && ./gradlew testDebugUnitTest`

6. **Do NOT modify any iOS or HamCore files** when porting to Android.
