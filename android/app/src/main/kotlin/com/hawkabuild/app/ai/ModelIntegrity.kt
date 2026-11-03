package com.hawkabuild.app.ai

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.security.MessageDigest

/** Build-time pinned artifact identity; checks are streamed, never whole-file reads. */
class ModelIntegrity private constructor(
    val fileName: String,
    val sha256: String,
    val sizeBytes: Long,
) {
    fun verifyAsset(context: Context, assetPath: String) {
        context.assets.open(assetPath).buffered().use { verify(it) }
    }

    fun verifyFile(file: File) {
        require(file.isFile && file.length() == sizeBytes) {
            "Model is incomplete: expected $sizeBytes bytes for $fileName. " + PREPARE
        }
        file.inputStream().buffered().use { verify(it) }
    }

    private fun verify(input: InputStream) {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            require(total <= sizeBytes) { "Model has unexpected size. " + PREPARE }
            digest.update(buffer, 0, count)
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        require(total == sizeBytes && actual == sha256) {
            "Model integrity check failed for $fileName. " + PREPARE
        }
    }

    companion object {
        private const val PREPARE = "Run python scripts/prepare_model_assets.py --help " +
            "in the source project, prepare the models, and rebuild/reinstall the app."

        fun read(context: Context, manifestAsset: String, expectedFileName: String): ModelIntegrity {
            val json = try {
                context.assets.open(manifestAsset).bufferedReader().use { reader ->
                    // Never read a model accidentally passed as a manifest.
                    val text = StringBuilder()
                    val buffer = CharArray(1024)
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        text.append(buffer, 0, count)
                        require(text.length <= 8192) { "Model integrity manifest is too large." }
                    }
                    JSONObject(text.toString())
                }
            } catch (error: Exception) {
                throw IllegalStateException("Model integrity manifest is missing or invalid. " + PREPARE, error)
            }
            val name = json.optString("fileName")
            val hash = json.optString("sha256").lowercase()
            val size = json.optLong("sizeBytes", -1)
            require(name == expectedFileName && hash.matches(Regex("[0-9a-f]{64}")) && size > 1024 * 1024) {
                "Model integrity manifest does not describe $expectedFileName. " + PREPARE
            }
            return ModelIntegrity(name, hash, size)
        }
    }
}
