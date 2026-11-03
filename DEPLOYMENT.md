# PipSpeak deployment guide

PipSpeak is **local-first**: every practice session, its full feedback, transcripts,
recordings and analyzed documents are saved in SQLite (Drift) on the device first.
Firebase is used for:

| Service | Used for |
| --- | --- |
| Firebase Authentication (email/password) | Accounts, sign-in, password reset |
| Cloud Firestore | `users/{uid}` profile, `users/{uid}/sessions/{sessionId}` numeric summaries, `usernames/{username}` lookup |

Raw audio/video, transcripts, detailed feedback, documents and file paths are **never uploaded**.
Profile photos stay on the device (Firebase Storage is not used).

Deploying Firebase **rules** and building/distributing the **Flutter app** are separate steps:
rules change what the cloud accepts; the app build is what users install.

## 1. Firebase project setup (console, one time)

Project: `app-builder-hackathon-f1b7b` (already referenced by `.firebaserc`,
`lib/firebase_options.dart` and `android/app/google-services.json`).

1. **Authentication → Sign-in method →** enable **Email/Password**.
2. **Authentication → Settings → Authorized domains:** add any web hosting domain if you ship the web build.
3. **Firestore Database → Create database →** Production mode, pick a location close to your users
   (e.g. `asia-southeast1`). The location cannot be changed later.
4. Optional but recommended: **App Check** → register the Android app with Play Integrity
   (web: reCAPTCHA Enterprise), monitor, then enforce for Firestore. App Check is an extra control;
   the security rules are the real access boundary.

The Spark (free) plan is enough: no Cloud Functions or Storage are used. Firestore free quota is
50k reads / 20k writes per day; each synced session is one write, plus a profile write when it changes.

## 2. Deploy security rules and indexes

```bash
npm install -g firebase-tools        # needs Node 18+
firebase login
firebase use app-builder-hackathon-f1b7b
firebase deploy --only firestore:rules,firestore:indexes
```

There are no Cloud Functions to deploy.

### Test the rules locally (Firebase Emulator, needs Java 21+)

```bash
cd firestore-tests
npm install
npm test        # runs firebase emulators:exec with a demo project; no real data is touched
```

## 3. Android

* `applicationId` is `com.gerardosison.app_builder_hackathon` to match the Android app registered in
  `google-services.json`. The Kotlin namespace (`com.hawkabuild.hawkabuild`) is unchanged.
  If you change the application ID, register the new package in Firebase and download a new
  `google-services.json`.
* Min SDK 26. Camera and microphone permissions are declared in `AndroidManifest.xml` and requested at runtime.
* For release builds add your SHA-1/SHA-256 in **Project settings → Your apps → Android** (needed for App Check / Play Integrity), and configure a release keystore in `android/app/build.gradle.kts` (currently signs with the debug key).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only when Drift tables change
flutter build apk --release          # or: flutter build appbundle --release (Play Store)
```

## 4. iOS / web

* **iOS** is not configured in Firebase yet (`firebase_options.dart` throws on iOS). Run
  `flutterfire configure` with an Apple machine, add `GoogleService-Info.plist`, and add camera/microphone
  usage strings to `ios/Runner/Info.plist`.
* **Web** works for sign-in and storage (`web/sqlite3.wasm`, `web/drift_worker.js`), but the native
  camera/pose/Whisper pipeline is Android-only. Build with `flutter build web` and host anywhere
  (add the domain to Authorized domains).

## 5. Local AI models

Models are not committed (size). Prepare verified weights and manifests before building; see [docs/local-models.md](docs/local-models.md):

| Model | Path | License |
| --- | --- | --- |
| Whisper `ggml-base-q5_1.bin` | `assets/models/whisper/` (not committed) | MIT |
| Qwen3 `qwen3-0.6b-q4_k_m.gguf` | `assets/models/llm/` (not committed) | Apache-2.0 |
| Google ML Kit Pose Detection | Model supplied by Android SDK dependency; no `.task` required | Google ML Kit terms |

If the LLM is missing, feedback falls back to rule-based coaching from the measured metrics.
If Whisper is missing, the practice session shows an error instead of fake feedback.

## 6. Sync behaviour (what users see)

Sync runs at sign-in/startup, when the app resumes, when connectivity returns, and every 60 s while the
app is open. There is **no background sync while the app is closed**. Status labels: *Saved on this device*,
*Waiting to sync*, *Syncing…*, *Synced*, *Sync failed* (tap to retry), *Cloud unreachable*.
Signing in requires a network connection the first time; afterwards Firebase keeps the session and the
app opens offline with local data. There is no separate offline password unlock.

## 7. Security notes

* Rules allow each user to read/write only their own `users/{uid}` tree, validate field names, types and
  ranges, and make completed sessions immutable (identical retries allowed).
* `usernames/{username}` is publicly readable so people can sign in with a username; it exposes the email
  linked to that username.
* Stars and levels are computed on the device; rules bound values (0–3 stars per session) but cannot
  prevent a modified client from submitting plausible fake sessions.
