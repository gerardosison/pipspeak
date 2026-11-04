# PipSpeak app-fixes: verification and next steps

Changes are on `app-fixes`. The latest fetched `main` commit,
`62e8ef6bc4cf74b8435cf28a783a4d373e6acd75`, is already included in this branch's
history. No commit or push was made to `main`.

## Corrected behavior

- Browser AI screens explain Android requirements before calling native plugins.
  TXT/DOCX/selectable-PDF extraction can run locally in Chrome without pretending
  to generate AI feedback. Saved scripts can be reopened or removed after restart.
- Retained accounts with cached profiles open offline. A new installation must
  retrieve its existing cloud profile before onboarding, preventing failed reads
  from replacing the user's saved profile with defaults.
- SQLite version 6 repairs the earlier version-5 schema variants by adding missing
  tables/columns, preserving pending sessions, stars and recognized local feedback.
  It does not reset the database.
- Account streams and detail requests are keyed by UID; account switching clears
  transient feedback. Mutations check the authenticated owner.
- Pending counts include profile edits. Cloud waits have a 20-second deadline;
  upload flags clear after acknowledgement, and stable IDs make late retries safe.
  Invalid optional metrics are omitted instead of blocking an entire session's sync.
- Public username reservations contain only UID. Email is used for first sign-in
  on a device; a saved username remains a local convenience. Rules protect older
  email-bearing reservations from public access.
- Account deletion paginates cloud history, pauses uploads during interrupted
  deletion, and removes referenced account recordings/photos and database rows.
  File cleanup refuses external paths, unrelated files and symlinks.
- Dark-mode text, input hints, buttons, onboarding, long chips and saved-document
  layouts were corrected. User progress and transcripts come from saved records;
  placeholder reward/transcript content and misleading settings were removed.
- Android release permissions include network access. Real camera/microphone
  consent and Android permission settings replace simulated permission actions.
- The native Qwen bridge preserves UTF-16/UTF-8 text across split tokens. Release
  builds reject missing or corrupt Qwen/Whisper artifacts before packaging.

## Verification

See the repository tests and [AI runtime acceptance guide](ai-runtime-validation.md).
Results for this update:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 199 tests passed.
- Chromium browser suite: 4 tests passed.
- `flutter build web --release --no-pub`: succeeded.
- Real Firestore emulator REST suite: 35 access/validation checks passed.
- Production local-AI coordinator/speech/feature checks: 43 passed.
- Model preparation Python suite: 6 tests passed.
- Production C++ Unicode bridge: passed all encoded/split-boundary cases.

These include database close/reopen, legacy migrations and account-boundary checks. Responsive tests cover 320×568, 640×280, 768×1024 and 1280×800 with 1.8× text
in both themes. These checks do not establish compatibility with every device.

## Run the updated browser preview

After saving any unrelated local work, update your existing checkout:

```powershell
git fetch origin
git switch app-fixes
git pull --ff-only origin app-fixes
flutter pub get
flutter run -d chrome --web-port 7357
```

Use a consistent browser origin/port to retain access to the same SQLite database.
Do not clear browser storage to fix an error: that can erase unsynced progress.

## Required before distribution

1. Deploy this branch's Firestore rules/indexes using your Firebase credentials.
   They have been tested locally, not deployed to your live project here:

   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes --project app-builder-hackathon-f1b7b
   ```

2. For native AI, prepare the actual model weights and integrity manifests using
   [local-models.md](local-models.md). The current Qwen runtime requires ARM64
   Android; Chrome cannot execute these Android plugins. Browser preview support
   is not browser Qwen/Whisper inference.
3. Install the Android SDK/NDK/CMake and run a native release build and the
   physical-device checks. This environment has no Android SDK or connected phone,
   so Android compilation, real inference latency, memory use, microphone drivers
   and pose behavior have not been verified here. Configure a release signing key
   before distribution; the current Android configuration uses a debug key.

The app syncs while open or resumed. It cannot upload progress while closed, erase
another offline device immediately, or restore device-only recordings/documents
from Firestore. A separate offline password-unlock feature is not implemented.
