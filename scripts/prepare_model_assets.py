#!/usr/bin/env python3
"""Prepare verified offline weights without loading them into memory.

Download mode obtains exact revision + LFS SHA-256/size from the official Hub
repository, then downloads that immutable revision over verified HTTPS.
Offline mode requires explicit upstream SHA-256 values for existing files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
MODELS = {
    "qwen": ("Qwen/Qwen3-0.6B-GGUF", "qwen3-0.6b-q4_k_m.gguf", "llm"),
    "whisper": ("ggerganov/whisper.cpp", "ggml-base-q5_1.bin", "whisper"),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_header(path: Path, model: str) -> None:
    if path.stat().st_size <= 1024 * 1024:
        raise ValueError(f"{path.name}: file is too small to be a real model")
    with path.open("rb") as source:
        header = source.read(24)
    if model == "qwen":
        magic, version, tensors, metadata = struct.unpack("<4sIQQ", header)
        if magic != b"GGUF" or version not in (2, 3) or not (
            1 <= tensors <= 100000 and 1 <= metadata <= 100000
        ):
            raise ValueError(f"{path.name}: invalid or unsupported GGUF header")
    elif header[:4] != b"lmgg":
        # ggml magic 0x67676d6c serialized little-endian by whisper.cpp.
        raise ValueError(f"{path.name}: invalid Whisper GGML header")


def request(url: str):
    if not url.startswith("https://huggingface.co/"):
        raise ValueError("Model metadata/download must start at official HTTPS Hub")
    return urlopen(Request(url, headers={"User-Agent": "PipSpeak-model-preparation/1"}), timeout=60)


def official_artifact(model: str) -> tuple[str, str, int, str]:
    repo, expected_name, _ = MODELS[model]
    with request(f"https://huggingface.co/api/models/{repo}/revision/main?blobs=true") as response:
        metadata = json.load(response)
    revision = metadata.get("sha", "")
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("Official model repository did not return an immutable revision")
    matches = [s for s in metadata.get("siblings", [])
               if s.get("rfilename", "").lower() == expected_name.lower()]
    if len(matches) != 1:
        raise ValueError(f"Official repository does not contain exactly {expected_name}; inspect upstream before updating")
    item = matches[0]
    lfs = item.get("lfs", {})
    digest, size = lfs.get("sha256", ""), lfs.get("size", 0)
    if not re.fullmatch(r"[a-f0-9]{64}", digest) or not isinstance(size, int) or size <= 1024 * 1024:
        raise ValueError("Upstream did not provide a usable LFS SHA-256 and size")
    url = f"https://huggingface.co/{repo}/resolve/{revision}/{quote(item['rfilename'], safe='/')}"
    return url, digest, size, revision


def download(url: str, target: Path, digest: str, size: int, model: str) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".download")
    try:
        with request(url) as source, temporary.open("wb") as output:
            total = 0
            while chunk := source.read(1024 * 1024):
                total += len(chunk)
                if total > size:
                    raise ValueError("Download exceeds published artifact size")
                output.write(chunk)
        verify(temporary, digest, size, model)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def verify(path: Path, expected_sha256: str, expected_size: int | None, model: str) -> None:
    if not re.fullmatch(r"[a-fA-F0-9]{64}", expected_sha256):
        raise ValueError("An upstream SHA-256 (64 hexadecimal characters) is required")
    if expected_size is not None and path.stat().st_size != expected_size:
        raise ValueError(f"{path.name}: size differs from upstream artifact")
    validate_header(path, model)
    if sha256_file(path) != expected_sha256.lower():
        raise ValueError(f"{path.name}: SHA-256 differs from upstream artifact")


def write_manifest(path: Path, model: str, digest: str, revision: str) -> None:
    repo, name, _ = MODELS[model]
    result = {
        "fileName": name,
        "sha256": digest.lower(),
        "sizeBytes": path.stat().st_size,
        "sourceRepository": repo,
        "sourceRevision": revision,
    }
    target = path.parent / "model-integrity.json"
    temporary = target.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true", help="Fetch official weights with published upstream SHA-256 verification")
    parser.add_argument("--model", choices=["all", *MODELS], default="all")
    parser.add_argument("--qwen-sha256", help="Official upstream SHA-256 for an existing local Qwen file")
    parser.add_argument("--whisper-sha256", help="Official upstream SHA-256 for an existing local Whisper file")
    args = parser.parse_args()
    selected = list(MODELS) if args.model == "all" else [args.model]
    for model in selected:
        repo, name, folder = MODELS[model]
        target = ROOT / "assets" / "models" / folder / name
        if args.download:
            url, digest, size, revision = official_artifact(model)
            print(f"Preparing {model}: {repo}@{revision}\nSHA-256: {digest}", flush=True)
            if target.is_file():
                try:
                    verify(target, digest, size, model)
                except ValueError:
                    download(url, target, digest, size, model)
            else:
                download(url, target, digest, size, model)
        else:
            digest = getattr(args, f"{model}_sha256")
            if digest is None:
                raise ValueError(f"Use --download or provide --{model}-sha256 from the official upstream file details")
            if not target.is_file():
                raise ValueError(f"Missing model: {target}")
            verify(target, digest, None, model)
            revision = "explicit-upstream-sha256"
        write_manifest(target, model, digest, revision)
        print(f"Verified {target.relative_to(ROOT)}; wrote model-integrity.json", flush=True)
    print("Rebuild and reinstall the app to package the verified assets and manifests.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        print(f"Model preparation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
