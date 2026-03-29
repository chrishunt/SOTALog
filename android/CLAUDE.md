# Android Agent Guide

> **Read [../DESIGN.md](../DESIGN.md) first.** It contains the app's design philosophy, architecture, data model, UI conventions, and interaction patterns. Understand the design before making any changes.

## Build & Run

### Prerequisites

- [Android Studio](https://developer.android.com/studio) (includes JDK, Android SDK, Gradle, emulator)
- On first launch, install Android SDK via SDK Manager

### Quick compile check

```sh
cd android && ./gradlew assembleDebug
```

### Run tests

```sh
cd android && ./gradlew testDebugUnitTest
```

### Android Emulator build, install, and launch

Create an emulator via Android Studio: **Tools → Device Manager → Create Virtual Device → Pixel 8 → API 35**.

Build and install:

```sh
cd android
./gradlew installDebug
adb shell am start -n com.sotalog.app/.MainActivity
```

Key details:
- **Application ID**: `com.sotalog.app`
- **Min SDK**: 28 (Android 9)
- **Target SDK**: 35 (Android 15)
- **Build output**: `app/build/outputs/apk/debug/app-debug.apk`

### SOTACat mock server (emulator testing)

To test SOTACat integration from the emulator, run the mock server:

```sh
sudo python3 ../tools/mock_sotacat.py
```

Note: The emulator may need port forwarding to reach the mock server on the host machine.

### Google Play deployment

**Signing**: The upload keystore is NOT in the repo. Generate one:

```sh
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store `upload-keystore.jks` securely. Configure in `app/build.gradle.kts` signing config.

**Build release AAB:**

```sh
cd android
./gradlew bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

Upload to Google Play Console via the web interface.

### Release checklist

**Pre-release:**

1. Review changes since last tag: `git log <last-tag>..HEAD --oneline`
2. Update `CHANGELOG.md` (at repo root)
3. Update `VERSION` file at repo root
4. Bump `versionCode` in `app/build.gradle.kts` (must increment for each upload)

**Test & verify:**

5. Run tests: `./gradlew testDebugUnitTest` (from `android/`)
6. Build and install on emulator to verify

**Build & upload:**

7. Build release AAB: `./gradlew bundleRelease`
8. Upload to Google Play Console

**Post-upload:**

9. Commit version bump + changelog: `git commit -m "Release <version>"`
10. Tag: `git tag v<version>` and push with `git push --tags`

## Architecture

- **UI**: Jetpack Compose + Material 3
- **Architecture**: 3-layer (UI / Domain / Data) with Unidirectional Data Flow
- **DI**: Hilt
- **Database**: Room
- **Networking**: OkHttp (direct) for QRZ and spot APIs, Retrofit for standard REST
- **Async**: Kotlin Coroutines + StateFlow
- **Navigation**: Jetpack Navigation Compose (type-safe routes)
- **Testing**: JUnit5 + MockK + Turbine

## Workflow

- After completing a change, always run tests first (`./gradlew testDebugUnitTest` from `android/`). If tests pass, build and install on the emulator so the user can test.
