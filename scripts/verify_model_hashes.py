#!/usr/bin/env python3
"""Verify packaged weights against the manifests produced at preparation time."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from prepare_model_assets import MODELS, ROOT, verify


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", choices=["all", *MODELS], default="all")
    args = parser.parse_args()
    selected = list(MODELS) if args.model == "all" else [args.model]
    for model in selected:
        _, filename, folder = MODELS[model]
        path = ROOT / "assets" / "models" / folder / filename
        manifest = json.loads((path.parent / "model-integrity.json").read_text(encoding="utf-8"))
        if manifest.get("fileName") != filename:
            raise ValueError("Manifest filename differs from expected artifact")
        verify(path, manifest["sha256"], manifest["sizeBytes"], model)
        print(f"Verified: {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, ValueError, OSError) as error:
        print(f"Model verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
