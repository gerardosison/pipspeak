# Local model files

Model weights are excluded from Git. Prepare them **before building**; a normal
Git checkout alone cannot run the local speech/chat/document models.

| Model | File path | Download |
| --- | --- | --- |
| Qwen3 0.6B Q8_0 | `assets/models/llm/qwen3-0.6b-q8_0.gguf` | [Hugging Face GGUF repository](https://huggingface.co/Qwen/Qwen3-0.6B-GGUF) |
| Whisper Base Q5_1 | `assets/models/whisper/ggml-base-q5_1.bin` | [Direct download](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin?download=true) |

The official Qwen repository currently publishes `Qwen3-0.6B-Q8_0.gguf`.
The downloader preserves that upstream spelling in its download URL and installs
it under the lowercase local asset name above. The earlier Q4_K_M expectation
was not present in the official repository. Q8_0 is a different quantization,
with larger storage and model-memory requirements than Q4_K_M; actual speed and
peak memory must be measured on the target phone. Do not rename a Q4 file as Q8.

The Flutter asset declarations in `pubspec.yaml` package these files as
`assets/models/llm/...` and `assets/models/whisper/...`. Keep the downloaded
weights out of commits; `.gitignore` excludes both formats.

## Prepare and verify models

From the repository root, with Python 3.10+ and internet access:

```powershell
python scripts/prepare_model_assets.py --check-sources
python scripts/prepare_model_assets.py --download
python scripts/verify_model_hashes.py
```

`--check-sources` checks the publisher's filenames, revision, hash and size
without downloading weights or creating manifests. Exact approved filenames may
be located inside a repository subfolder; the downloader retains that upstream
path while installing the canonical local asset name. Multiple matching files
are rejected rather than choosing an arbitrary one.

If the requested quantization is absent, the error lists published model files.
Provide that output when reporting the problem. Do not rename another quantization
or a split-model part into the expected filename, invent an integrity manifest, or
disable release verification. A missing source artifact needs a reviewed source
or model update before the release can be built.

The preparation script queries the official model repositories for the exact
commit revision, LFS SHA-256 and size, then downloads that immutable revision.
HTTPS certificate verification stays enabled. Downloads stream to a temporary
file; a model is installed only after its published hash, size, and format pass.
The script stops if the upstream metadata is missing or the expected filename
changes. It does not silently substitute another model or accept an HTML error
page / Git LFS pointer as a model.

You can prepare just one model with `--model whisper` or `--model qwen`.
The chatbot and document analyzer require Qwen; basic measured speech feedback
can still work without Qwen, but spoken transcription requires Whisper.

If you already downloaded the weights, copy them to the paths above. Obtain each
SHA-256 from the **official repository's file details** and run:

```powershell
python scripts/prepare_model_assets.py --qwen-sha256 REPLACE_WITH_OFFICIAL_QWEN_SHA256 --whisper-sha256 REPLACE_WITH_OFFICIAL_WHISPER_SHA256
```

Those arguments are placeholders; do not enter them literally or use a hash of
an untrusted download as its own proof of authenticity. No real upstream hashes
are invented or embedded in source. Verified source revision/hash/size are saved
in each model folder's `model-integrity.json`, which must be included in the app
alongside the weights. Review these small manifests in source control when
upgrading models; they make the exact packaged version auditable.

Rebuild and reinstall after preparation:

```powershell
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The canonical model location is the **Flutter assets path**. Do not put a second
Qwen copy under `android/app/src/main/assets/models/llm`; it duplicates APK size
and is no longer used by the loader. Native Android reads
`flutter_assets/assets/models/llm/...` from the APK and copies it with bounded
buffers into private app storage. This avoids loading the whole GGUF into Dart
memory. The copy is hash-checked before becoming the active model. A damaged or
outdated cached copy is replaced only after a new copy verifies. Full native
model parsing still happens in llama.cpp; a correct file hash is not a guarantee
that a particular phone/GPU can execute it.

## Pose model and status

The production camera pipeline uses **Google ML Kit Pose Detection**. Its model
is supplied by the Android SDK dependency; the legacy
`android/app/src/main/assets/mediapipe/pose_landmarker_lite.task` is a text
placeholder and must not be reported as a working model. No `.task` download is
required for ML Kit. A legacy asset availability probe does not prove detector
initialization or camera frame inference works.

Model status now reflects runtime probes rather than hard-coded `true` values.
Qwen artifact availability is distinct from a loaded inference context. Verify
chat generation, recording transcription and live pose frames separately on a
physical ARM64 Android device.

## Mobile acceptance checks

Record first-load time, warm-load time, first-token latency, tokens/second,
transcription time per audio minute, peak memory and temperature on the target
device. Test a cold app start, reopen, airplane mode, interrupted model copy,
long chat, document analysis and returning from an active generation. Do not
promise every GPU recommendation is faster than CPU inference; benchmark release
builds on the intended low/mid-range phones.

The repository's preparation tests exercise corrupted, truncated and placeholder
artifacts without shipping pretend model weights:

```powershell
python -m unittest discover -s scripts/tests -v
flutter test test/model_assets_test.dart
```

Whisper.cpp is built for Android `arm64-v8a` and `armeabi-v7a`. The current
Qwen plugin is ARM64-only, so Qwen local inference requires a 64-bit Android
runtime. Whisper input audio must be a 16 kHz, 16-bit PCM WAV file; see
[`whisper-android.md`](whisper-android.md) for the service call.
