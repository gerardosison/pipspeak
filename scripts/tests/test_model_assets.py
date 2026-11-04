import importlib.util
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "prepare_model_assets", Path(__file__).resolve().parents[1] / "prepare_model_assets.py"
)
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


class ModelPreparationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "qwen3-0.6b-q8_0.gguf"

    def write_fixture(self):
        self.path.write_bytes(struct.pack("<4sIQQ", b"GGUF", 3, 100, 20) + bytes(1024 * 1024))
        return assets.sha256_file(self.path)

    def test_validated_fixture_writes_exact_size_and_hash_manifest(self):
        digest = self.write_fixture()
        assets.verify(self.path, digest, self.path.stat().st_size, "qwen")
        assets.write_manifest(self.path, "qwen", digest, "upstream-revision")
        manifest = json.loads((self.path.parent / "model-integrity.json").read_text())
        self.assertEqual(manifest["sha256"], digest)
        self.assertEqual(manifest["sizeBytes"], self.path.stat().st_size)
        self.assertEqual(manifest["sourceRevision"], "upstream-revision")

    def test_corrupt_file_is_rejected_even_when_size_and_header_match(self):
        digest = self.write_fixture()
        with self.path.open("r+b") as output:
            output.seek(100)
            output.write(b"damaged")
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            assets.verify(self.path, digest, None, "qwen")

    def test_truncated_file_is_rejected(self):
        digest = self.write_fixture()
        with self.assertRaisesRegex(ValueError, "size"):
            assets.verify(self.path, digest, self.path.stat().st_size + 1, "qwen")

    def test_placeholders_and_wrong_format_are_rejected(self):
        self.path.write_text("Git LFS pointer or download error page")
        with self.assertRaisesRegex(ValueError, "too small"):
            assets.validate_header(self.path, "qwen")
        self.path.write_bytes(bytes(1024 * 1024 + 1))
        with self.assertRaisesRegex(ValueError, "GGUF"):
            assets.validate_header(self.path, "qwen")

    def test_whisper_magic_matches_upstream_little_endian_format(self):
        self.path.write_bytes(b"lmgg" + bytes(1024 * 1024))
        assets.validate_header(self.path, "whisper")

    def test_unknown_or_non_https_artifact_url_is_rejected_before_request(self):
        with self.assertRaises(ValueError):
            assets.request("http://huggingface.co/file")
        with self.assertRaises(ValueError):
            assets.request("https://example.com/model.gguf")

    def metadata(self, *paths):
        return {
            "sha": "a" * 40,
            "siblings": [
                {"rfilename": path, "lfs": {"sha256": "b" * 64, "size": 2 * 1024 * 1024}}
                for path in paths
            ],
        }

    def test_nested_approved_artifact_preserves_upstream_path_and_revision(self):
        path = "Q8_0/Qwen3-0.6B-Q8_0.gguf"
        metadata = self.metadata(path)
        with patch.object(assets, "request", return_value=io.BytesIO(json.dumps(metadata).encode())):
            url, digest, size, revision = assets.official_artifact("qwen")
        self.assertEqual(url, "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/" + "a" * 40 + "/" + path)
        self.assertEqual(digest, "b" * 64)
        self.assertEqual(size, 2 * 1024 * 1024)
        self.assertEqual(revision, "a" * 40)

    def test_official_q8_listing_downloads_verifies_and_writes_canonical_manifest(self):
        # Regression for the publisher file list supplied by the user. The bytes,
        # revision and LFS metadata below are test fixtures, not real model data.
        fixture_digest = self.write_fixture()
        fixture_bytes = self.path.read_bytes()
        revision = "c" * 40
        source_name = "Qwen3-0.6B-Q8_0.gguf"
        metadata = {
            "sha": revision,
            "siblings": [
                {"rfilename": ".gitattributes"},
                {"rfilename": "LICENSE"},
                {"rfilename": source_name, "lfs": {
                    "sha256": fixture_digest, "size": len(fixture_bytes),
                }},
                {"rfilename": "README.md"},
                {"rfilename": "params"},
            ],
        }
        metadata_url = "https://huggingface.co/api/models/Qwen/Qwen3-0.6B-GGUF/revision/main?blobs=true"
        weight_url = f"https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/{revision}/{source_name}"
        requested = []

        def response(url):
            requested.append(url)
            if url == metadata_url:
                return io.BytesIO(json.dumps(metadata).encode())
            self.assertEqual(url, weight_url)
            return io.BytesIO(fixture_bytes)

        root = Path(self.directory.name) / "application"
        with patch.object(assets, "ROOT", root), patch.object(assets, "request", side_effect=response), patch(
            "sys.argv", ["prepare_model_assets.py", "--download", "--model", "qwen"]
        ):
            self.assertEqual(assets.main(), 0)
        target = root / "assets/models/llm/qwen3-0.6b-q8_0.gguf"
        manifest = json.loads((target.parent / "model-integrity.json").read_text())
        self.assertEqual(requested, [metadata_url, weight_url])
        self.assertEqual(target.read_bytes(), fixture_bytes)
        self.assertEqual(manifest, {
            "fileName": "qwen3-0.6b-q8_0.gguf",
            "sha256": fixture_digest,
            "sizeBytes": len(fixture_bytes),
            "sourceRepository": "Qwen/Qwen3-0.6B-GGUF",
            "sourceRevision": revision,
        })
        self.assertFalse(target.with_suffix(".gguf.download").exists())

    def test_missing_quantization_lists_published_files_without_substitution(self):
        metadata = self.metadata("Qwen3-0.6B-Q4_K_M.gguf")
        with self.assertRaisesRegex(ValueError, "Published model files: 'Qwen3-0.6B-Q4_K_M.gguf'"):
            assets.artifact_from_metadata("qwen", metadata)

    def test_ambiguous_artifact_does_not_pick_arbitrary_directory(self):
        metadata = self.metadata("old/qwen3-0.6b-q8_0.gguf", "new/qwen3-0.6b-q8_0.gguf")
        with self.assertRaisesRegex(ValueError, "found 2"):
            assets.artifact_from_metadata("qwen", metadata)

    def test_split_artifact_is_not_renamed_into_a_complete_model(self):
        metadata = self.metadata("qwen3-0.6b-q8_0-00001-of-00002.gguf")
        with self.assertRaisesRegex(ValueError, "found 0"):
            assets.artifact_from_metadata("qwen", metadata)

    def test_metadata_requires_immutable_revision_hash_size_and_safe_path(self):
        valid = self.metadata("qwen3-0.6b-q8_0.gguf")
        for metadata in (
            {**valid, "sha": "main"},
            {**valid, "siblings": [{"rfilename": "qwen3-0.6b-q8_0.gguf"}]},
            self.metadata("../qwen3-0.6b-q8_0.gguf"),
            self.metadata("/qwen3-0.6b-q8_0.gguf"),
        ):
            with self.subTest(metadata=metadata), self.assertRaises(ValueError):
                assets.artifact_from_metadata("qwen", metadata)

    def test_failed_download_preserves_existing_model_and_removes_partial(self):
        digest = self.write_fixture()
        original = self.path.read_bytes()
        with patch.object(assets, "request", return_value=io.BytesIO(b"error response")):
            with self.assertRaises(ValueError):
                assets.download("https://huggingface.co/model", self.path, digest, len(original), "qwen")
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse(self.path.with_suffix(".gguf.download").exists())


if __name__ == "__main__":
    unittest.main()
