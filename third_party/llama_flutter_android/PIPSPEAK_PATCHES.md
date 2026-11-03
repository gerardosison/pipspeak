# PipSpeak native runtime patch

Source: `llama_flutter_android` 0.2.6 from pub.dev, originally published at
https://github.com/dragneel2074/Llama-Flutter. Upstream package and llama.cpp
licenses are retained. Archive line endings/trailing whitespace are normalized.
This is source code, not model weights.

This local path dependency makes the following fixes reproducible for every
teammate and release build, without editing a developer's Pub cache:

- Dart Stop waits for the terminal callback instead of permitting another
  request while JNI is still decoding.
- Host invocation failures close the corresponding stream. A delayed reply for
  an old request cannot terminate the next request.
- Kotlin Stop joins the native generation job; cancellation does not cancel the
  coroutine out from underneath blocking JNI. Concurrent jobs are rejected.
- Engine teardown defers freeing until native generation/loading completes.
  A dispose timeout never frees a context still in use.
- Native inference resets the KV cache before processing a complete new prompt.
  This prevents repeated-history accumulation and cross-feature/account context.
- Native cancellation is reset before scheduling a request, not inside the
  decode function, and the context has an abort callback for active CPU decode.
- Private prompt text and per-token IDs are no longer written to Android logs.
- ChatML with `/no_think` seeds Qwen3's empty thinking block, rather than spending
  the short mobile output budget on hidden reasoning.

The app coordinator adds context limits, serialization, request-specific
cancellation, deadlines and a fail-closed state if stopping does not complete.

Regression tests: `flutter test test/llama_plugin_lifecycle_test.dart`.
Actual JNI/Android compilation and physical-device inference are separate checks;
passing the Dart tests does not validate GPU/ABI support or model performance.
