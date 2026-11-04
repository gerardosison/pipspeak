# PipSpeak (hawkabuild)

Offline-first Flutter (Material 3) public-speaking practice app with local
Whisper transcription, ML Kit pose analysis, optional Qwen coaching, SQLite
storage, and Firebase account/progress synchronization. Native AI requires a
supported Android device and separately prepared model weights.

## Run

Requires Flutter 3.47+ and Dart 3.13+ for the locked dependencies.
Prepare verified model weights using `docs/local-models.md` before an Android AI build.

```sh
flutter pub get
flutter run
```

### Chrome on Windows

```powershell
flutter run -d chrome --web-port 7357
```

Keep the same port when restarting: browser data belongs to an origin (host and
port). Changing ports, clearing browser data or using a private window uses different storage.

Chrome supports account screens, SQLite-backed history/progress, theme settings,
local profile photos, and local document text extraction. The current Qwen,
Whisper and pose implementations require Android; they cannot run in Chrome.
Browser screens explain this before invoking native plugins. Document text
extraction in the browser is explicitly labeled as a preview without AI analysis.
A successful browser build does not validate Android model performance.

### Android emulator and device builds

Install the Android SDK, the NDK version selected by Flutter, and CMake 3.22.1
through Android Studio's SDK Manager, then verify the setup and accept the SDK
licenses:

```sh
flutter doctor -v
flutter doctor --android-licenses
```

List and start an emulator if needed, then run on a specific emulator or
connected phone (replace `EMULATOR_ID` and `DEVICE_ID` with IDs from the list):

```sh
flutter emulators
flutter emulators --launch EMULATOR_ID
flutter devices
flutter run -d DEVICE_ID
```

This builds native libraries for the selected target architecture. x64
emulators are supported for app and camera testing; the bundled local LLM
currently provides native code on ARM64 devices only. For a standalone debug
APK, choose the target explicitly to avoid compiling unneeded ABIs:

```sh
flutter build apk --debug --target-platform android-arm64  # ARM phones
flutter build apk --debug --target-platform android-x64     # x64 emulators
```

## Structure

- `lib/app/` — theme (`app_colors`, `app_typography`, `app_theme`), `app_router` (go_router), providers (Riverpod)
- `lib/core/models` — plain Dart data classes
- `lib/core/services` — service interfaces + mock implementations (auth, permissions, speech analysis, documents)
- `lib/core/widgets` — reusable Pip widgets (buttons, cards, chips, fields, mascot, live meters, star/level)
- `lib/features/*/presentation` — screens: auth, onboarding, home (bottom nav), practice, feedback, documents, progress, profile, settings
- `lib/data/` — local-first Drift repositories and Firestore synchronization
- `lib/features/ai/` — local model loading, speech/pose analysis, and coaching

## Local AI setup and verification

Prepare verified weights before building. See [docs/local-models.md](docs/local-models.md)
and [docs/ai-runtime-validation.md](docs/ai-runtime-validation.md) for setup,
regression checks, platform limits, and physical-device acceptance checks.
Legacy mock services and development dashboards remain in the repository; the
production providers use Whisper, ML Kit, and the local document/feedback services.

## Notes

- Light & dark themes; ThemeMode switch in Settings.
- Business rule: stars earned only on improvement; level n needs 10*n stars.

## Accounts, storage and sync

- Sign-in uses Firebase Authentication (email/password). A previously saved username can identify an account on the same device; a new device needs the email. Public username reservations contain only a UID.
- Everything is saved on the device first in SQLite (Drift, `lib/data/local/app_database.dart`):
  profile, practice sessions with full feedback, analyzed documents and settings.
- Only profile fields and numeric session summaries sync to Firestore
  (`users/{uid}`, `users/{uid}/sessions/{id}`). Recordings, transcripts and documents stay local.
- Stars: the first session per goal/language is a baseline (0 stars); later sessions earn
  1/2/3 stars for beating the average of the last 3 compatible sessions by +2/+5/+10 points.
  Level n needs 10 × n more stars (Level 2 at 10, Level 3 at 30, Level 4 at 60 total).

See [DEPLOYMENT.md](DEPLOYMENT.md) for Firebase setup, rules deployment, builds and models.

### Checks

```bash
flutter analyze && flutter test
cd firestore-tests && npm install && npm test   # Firestore rules (emulator, Java 21+)
```
