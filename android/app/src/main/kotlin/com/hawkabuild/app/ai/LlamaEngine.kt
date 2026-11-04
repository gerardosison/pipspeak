package com.hawkabuild.app.ai

import android.content.Context
import android.os.Build
import android.os.Process
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Validates the Qwen GGUF packaged in the Android app.
 *
 * Inference is owned by the llama_flutter_android Dart plugin. This class must
 * not return coaching text because that would bypass the real model.
 */
class LlamaEngine(private val context: Context) {
    private var isLoaded = false
    private val modelAsset = "flutter_assets/assets/models/llm/qwen3-0.6b-q8_0.gguf"
    private val manifestAsset = "flutter_assets/assets/models/llm/model-integrity.json"
    private var verifiedPath: String? = null
    private var verifiedModified = -1L
    private var verifiedLength = -1L

    fun initialize(): Boolean {
        isLoaded = try {
            // Availability checks follow the same validated path as inference.
            prepareModelFile()
            true
        } catch (_: Exception) {
            false
        }
        return isLoaded
    }

    fun generateFeedback(prompt: String): String {
        throw UnsupportedOperationException(
            "Qwen inference is provided by llama_flutter_android on the Dart side."
        )
    }

    /** Copies the bundled GGUF asset to a path llama.cpp can memory-map. */
    @Synchronized
    fun prepareModelFile(): String {
        check(Process.is64Bit() && Build.SUPPORTED_ABIS.contains("arm64-v8a")) {
            "Local Qwen requires an ARM64 Android runtime. Use a supported physical " +
                "64-bit ARM phone and an android-arm64 build."
        }
        val modelFile = File(context.filesDir, "llm/qwen3-0.6b-q8_0.gguf")
        val integrity = ModelIntegrity.read(context, manifestAsset, modelFile.name)
        if (verifiedPath == modelFile.absolutePath &&
            verifiedModified == modelFile.lastModified() &&
            verifiedLength == modelFile.length() && modelFile.isFile) {
            return modelFile.absolutePath
        }

        if (modelFile.isFile) {
            try {
                integrity.verifyFile(modelFile)
                validateHeader(modelFile)
                return remember(modelFile)
            } catch (_: Exception) {
                // Replace an old or damaged copy only after the new copy verifies.
            }
        }

        val parent = modelFile.parentFile
            ?: throw IllegalStateException("Could not create the local model directory.")
        if (!parent.exists() && !parent.mkdirs()) {
            throw IllegalStateException("Could not create the local model directory.")
        }

        val temporaryFile = File(parent, "${modelFile.name}.tmp")
        try {
            context.assets.open(modelAsset).buffered().use { input ->
                temporaryFile.outputStream().buffered().use { output -> input.copyTo(output) }
            }
            integrity.verifyFile(temporaryFile)
            validateHeader(temporaryFile)
        } catch (error: Exception) {
            temporaryFile.delete()
            throw IllegalStateException(
                "The bundled Qwen model is missing, incomplete, or failed validation. " +
                    "Run python scripts/prepare_model_assets.py --help, prepare models, " +
                    "and rebuild/reinstall the app.", error,
            )
        }
        if (modelFile.exists() && !modelFile.delete()) {
            temporaryFile.delete()
            throw IllegalStateException("Could not replace the incomplete Qwen model file.")
        }
        if (!temporaryFile.renameTo(modelFile)) {
            temporaryFile.delete()
            throw IllegalStateException("Could not finalize the local Qwen model file.")
        }
        return remember(modelFile)
    }

    fun isReady(): Boolean = isLoaded

    private fun remember(file: File): String {
        verifiedPath = file.absolutePath
        verifiedModified = file.lastModified()
        verifiedLength = file.length()
        return file.absolutePath
    }

    private fun validateHeader(file: File) {
        file.inputStream().use { input ->
            val header = ByteArray(24)
            require(input.read(header) == header.size) { "Qwen GGUF header is truncated." }
            val bytes = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
            val version = bytes.getInt(4)
            val tensors = bytes.getLong(8)
            val metadata = bytes.getLong(16)
            require(String(header, 0, 4, Charsets.US_ASCII) == "GGUF" &&
                version in 2..3 && tensors in 1L..100000L && metadata in 1L..100000L) {
                "Invalid or unsupported Qwen GGUF header."
            }
        }
    }
}
