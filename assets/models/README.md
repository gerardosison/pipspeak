# PipSpeak model assets

The two canonical weight files are configured for Git LFS. Integrity manifests
are small, ordinary Git files containing the exact publisher revision, SHA-256
and byte count. Upload the real model files and their matching manifests together;
do not commit hand-written manifests or ordinary Git copies of the weights.

- **Qwen3 0.6B Q8_0**: published by the Qwen team at
  https://huggingface.co/Qwen/Qwen3-0.6B-GGUF under Apache-2.0.
  License: `llm/LICENSE-Qwen-Apache-2.0.txt`.
- **Whisper Base Q5_1**: OpenAI Whisper model, quantized for whisper.cpp and
  published at https://huggingface.co/ggerganov/whisper.cpp under MIT.
  OpenAI license: `whisper/LICENSE-Whisper-MIT.txt`.
  The whisper.cpp source and its license are retained under `third_party/whisper.cpp`.

See [upload and clone instructions](../../docs/sharing-model-assets.md).
