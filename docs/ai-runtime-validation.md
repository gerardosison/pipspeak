# Local AI runtime fixes and verification

## Scope

Chat, document analysis and optional speech coaching share one Qwen context. The
coordinator now shares model initialization, serializes inference, limits prompt
history, supports per-request cancellation, and enforces idle/total response
limits. A request waiting in the queue cannot stop another request. If native
stopping fails or times out, the runtime refuses more inference until app restart
instead of overlapping native contexts.

Cancelling while a model loads returns control to the caller, but cannot cancel
the native model load itself. Other callers reuse that same loading operation.
A load timeout likewise does not start a second load over an unfinished one.

The mobile baseline is 2,048 context tokens, at most 512 generated tokens, and
1–4 CPU threads. GPU offload is deliberately disabled until a supported device
has been benchmarked. This is a compatibility baseline, not a claim of optimal
speed. UTF-8 byte budgeting conservatively bounds Qwen's byte-level tokenization;
long chat drops oldest complete turns, and long documents explicitly sample
beginning/middle/end passages. The app does not claim every page was analyzed.

## Pinned native plugin

The app uses the source-pinned local `third_party/llama_flutter_android` fork of
0.2.6. Its documented changes wait for native Stop completion, avoid freeing an
active context, reset complete-prompt KV state, remove private prompt logging,
and seed Qwen3 non-thinking output. See that folder's `PIPSPEAK_PATCHES.md`.
Do not revert to the hosted dependency without checking these fixes upstream.

## Weights are required

Follow [local-models.md](local-models.md). Both actual weights and their verified
`model-integrity.json` manifests must be prepared before building. The app now
rejects missing, corrupt, stale or placeholder artifacts with setup instructions.
It never downloads replacement models silently or accepts a file merely because
it is larger than 1 MB. Keep model weights out of Git.

The canonical Qwen path is `assets/models/llm/qwen3-0.6b-q4_k_m.gguf`.
Android copies this asset into private storage with bounded buffers and validates
its SHA-256 before reuse. An ARM64 Android process is required by the Qwen plugin.

## Measurements and historical compatibility

Whisper returns actual segment start/end times and its native error status.
Speech rate uses WAV sample duration, rather than an invented fallback duration.
Pause statistics are estimated gaps between ASR segments, not calibrated acoustic
silence detection. Only conservative hesitation spellings are counted; transcript
recognition can omit hesitations, so a zero count is not proof of perfect fluency.

Pose scores are image-relative heuristics, not clinical measurements or eye
contact detection. Shoulder scoring is invariant to mirroring; coordinate
normalization accounts for Android image rotation. Movement is displayed as a
percentage of frame width. The legacy `bodySwayCm` storage/API name remains for
compatibility but is not a physical distance. Camera movement/distance affect it.

New sessions use scoring version `v2`; previously earned stars are preserved, but
old `v1` measurements are not used as improvement baselines for the corrected
measurements. The first session under the corrected version is a new baseline.

## Automated checks

From the repository root:

```powershell
python -m unittest discover -s scripts/tests -v
dart scripts/test_local_ai_runtime.dart
dart scripts/test_ai_features.dart
dart scripts/test_speech_pose.dart
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

The standalone Dart checks import production code and inject only the native
inference boundary. They verify orchestration, text budgeting, feedback fallback,
and measurement math. They do not execute llama.cpp, Whisper JNI, camera drivers,
or Firebase. Flutter tests additionally exercise method-channel decoding and UI
compatibility, but native builds and device tests remain necessary.

## Physical-device acceptance

Use a release build on the actual target ARM64 phone. Record model filenames,
source revisions, Android version, phone model/RAM, and free storage. Do not
include private recordings/transcripts in shared logs.

1. Prepare verified weights; build/install; open chat in airplane mode. Check
   first-load and warm-load times, useful responses, and first-token latency.
2. Ask 20 consecutive questions. Confirm old turns are trimmed safely and no
   context overflow occurs. Cancel both during loading and during generation.
3. Leave chat while it generates; start document analysis. Confirm the old job
   stops and the next job runs without simultaneous native inference.
4. Analyze readable English/Filipino PDF, DOCX and TXT scripts. Test unreadable,
   oversized and long documents; sampled coverage must be disclosed.
5. Record a known-duration speech with microphone and camera. Check real
   transcription, pace, conservative fillers, segment-gap estimates, mirrored
   posture, and frame-relative movement. Test permissions denied/no person.
6. Interrupt camera/model work by leaving the screen and resuming. Check that
   the app neither freezes indefinitely nor closes active native resources early.
7. Remove/corrupt a cached model in a controlled debug installation. Confirm the
   verified bundled artifact replaces it or a clear integrity error appears.
8. Complete practice without optional Qwen. Measured rule-based feedback and the
   local save should still succeed when usable speech/pose evidence exists.
9. Check saved history displays the selected session rather than the latest
   in-memory capture; reconnect and verify existing progress sync still works.
10. Measure transcription time/audio minute, tokens/second, peak memory and
    temperature. Repeat under low memory and after a cold restart. Adjust GPU,
    model size, context and thread settings only against these measurements.

Do not call the native pipeline validated until these tests run with real model
weights. A successful coordinator test or web build does not establish phone
inference speed, memory stability, or Android ABI/plugin compatibility.
