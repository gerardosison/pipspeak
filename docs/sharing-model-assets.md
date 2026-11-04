# Share the complete AI assets through GitHub LFS

Qwen is approximately 610 MiB, above GitHub's normal 100 MB per-file limit.
The repository tracks its canonical Qwen and Whisper files through **Git LFS**.
The small integrity manifests and license texts use ordinary Git. This consumes
the repository owner's Git LFS storage and download allowance.

The repository configuration alone does not upload model contents. The maintainer
must run these steps on the computer holding the verified weights. The Codex
cloud workspace cannot read files on the maintainer's Windows laptop.

## Upload from the Windows project folder

Use the `app-fixes` branch. Run each command after the preceding one succeeds.
If `git lfs version` is unavailable, install Git LFS from https://git-lfs.com/
and reopen PowerShell before continuing.

```powershell
git lfs version
git lfs install
git pull --ff-only origin app-fixes
python scripts/verify_model_hashes.py
git add -- assets/models/llm/qwen3-0.6b-q8_0.gguf assets/models/llm/model-integrity.json assets/models/whisper/ggml-base-q5_1.bin assets/models/whisper/model-integrity.json
git lfs ls-files
git commit -m "Add verified Qwen and Whisper model assets via Git LFS" -- assets/models/llm/qwen3-0.6b-q8_0.gguf assets/models/llm/model-integrity.json assets/models/whisper/ggml-base-q5_1.bin assets/models/whisper/model-integrity.json
git push origin app-fixes
```

Before the commit, `git lfs ls-files` should list both weight filenames. The push
uploads their contents through LFS before publishing the Git commit. A successful
Git-only commit is not evidence that the LFS upload completed; check the push
result. No model filename needs to be changed manually.

These commands select only the two weights and their manifests. Build caches,
recordings, database files, signing keys and private credentials do not belong
in the shared model assets.

## Retrieve on another computer

Install Git LFS, clone/check out `app-fixes`, then run from the project folder:

```powershell
git lfs install
git lfs pull
python scripts/verify_model_hashes.py
flutter pub get
```

Do not build a native AI release from LFS pointer files. Verification rejects
those small text pointers instead of treating them as actual weights. After
successful retrieval and verification, build for a supported Android device as
described in [local-models.md](local-models.md).
