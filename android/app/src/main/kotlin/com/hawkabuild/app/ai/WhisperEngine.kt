package com.hawkabuild.app.ai

import android.content.Context
import android.util.Log
import com.whispercpp.whisper.WhisperContext
import kotlinx.coroutines.runBlocking
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** On-device Whisper.cpp inference for 16 kHz PCM WAV recordings. */
class WhisperEngine(private val context: Context) {
    private val modelAsset = "flutter_assets/assets/models/whisper/ggml-base-q5_1.bin"
    @Volatile private var whisperContext: WhisperContext? = null
    @Volatile private var loadError: Throwable? = null

    @Synchronized
    fun initialize(): Boolean {
        if (whisperContext != null) return true
        return try {
            // A manifest pins the actual artifact; a filename or size threshold
            // cannot distinguish a valid model from a truncated/wrong download.
            ModelIntegrity.read(
                context,
                "flutter_assets/assets/models/whisper/model-integrity.json",
                "ggml-base-q5_1.bin",
            ).verifyAsset(context, modelAsset)
            whisperContext = WhisperContext.createContextFromAsset(
                context.assets,
                modelAsset,
            )
            loadError = null
            true
        } catch (error: Throwable) {
            loadError = error
            Log.e(TAG, "Failed to load Whisper model asset: $modelAsset", error)
            false
        }
    }

    fun initializationError(): String = loadError?.message
        ?: "Whisper model could not be loaded. Verify model assets and rebuild the app."

    @Synchronized
    fun transcribe(audioPath: String, language: String = "auto"): Map<String, Any> {
        require(audioPath.isNotBlank()) { "Audio path is empty." }
        if (!initialize()) {
            throw IllegalStateException(initializationError(), loadError)
        }

        val file = File(audioPath)
        require(file.isFile) { "Audio file does not exist: $audioPath" }
        val wav = readPcm16Wav(file)
        val transcription = runBlocking {
            whisperContext!!.transcribeWithSegments(
                data = wav.samples,
                language = language,
            )
        }
        return mapOf(
            "text" to transcription.text,
            "segments" to transcription.segments.map {
                mapOf(
                    "startSeconds" to it.startSeconds,
                    "endSeconds" to it.endSeconds,
                    "text" to it.text,
                )
            },
            "durationSeconds" to wav.samples.size / SAMPLE_RATE.toDouble(),
            "language" to transcription.language,
        )
    }

    private fun readPcm16Wav(file: File): WavAudio {
        val bytes = file.readBytes()
        require(bytes.size >= 44) { "Audio file is too short to be a WAV file." }
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        require(readFourCc(buffer, 0) == "RIFF" && readFourCc(buffer, 8) == "WAVE") {
            "Whisper input must be a PCM WAV file."
        }

        var offset = 12
        var channels = 0
        var sampleRate = 0
        var bitsPerSample = 0
        var audioFormat = 0
        var dataOffset = -1
        var dataLength = 0

        while (offset + 8 <= bytes.size) {
            val chunkName = readFourCc(buffer, offset)
            val chunkLength = buffer.getInt(offset + 4).toLong() and 0xffffffffL
            val contentOffset = offset + 8
            require(chunkLength <= Int.MAX_VALUE && contentOffset + chunkLength <= bytes.size) {
                "WAV file contains an invalid chunk."
            }
            when (chunkName) {
                "fmt " -> if (chunkLength >= 16) {
                    audioFormat = buffer.getShort(contentOffset).toInt() and 0xffff
                    channels = buffer.getShort(contentOffset + 2).toInt() and 0xffff
                    sampleRate = buffer.getInt(contentOffset + 4)
                    bitsPerSample = buffer.getShort(contentOffset + 14).toInt() and 0xffff
                }
                "data" -> {
                    dataOffset = contentOffset
                    dataLength = chunkLength.toInt()
                }
            }
            offset = contentOffset + chunkLength.toInt() + (chunkLength.toInt() and 1)
        }

        require(audioFormat == 1 && bitsPerSample == 16) {
            "Audio must use uncompressed 16-bit PCM."
        }
        require(sampleRate == SAMPLE_RATE) {
            "Audio must be 16 kHz; received ${sampleRate} Hz."
        }
        require(channels == 1 || channels == 2) {
            "Audio must be mono or stereo."
        }
        require(dataOffset >= 0 && dataLength >= channels * 2) {
            "WAV file has no usable audio data."
        }

        val frameCount = dataLength / (channels * 2)
        val samples = FloatArray(frameCount)
        var cursor = dataOffset
        for (frame in 0 until frameCount) {
            var sum = 0
            repeat(channels) {
                sum += buffer.getShort(cursor).toInt()
                cursor += 2
            }
            samples[frame] = (sum.toFloat() / channels / 32768f).coerceIn(-1f, 1f)
        }
        return WavAudio(samples)
    }

    private fun readFourCc(buffer: ByteBuffer, offset: Int): String =
        String(ByteArray(4) { index -> buffer.get(offset + index) }, Charsets.US_ASCII)

    private data class WavAudio(val samples: FloatArray)

    companion object {
        private const val TAG = "HawkABuildWhisper"
        private const val SAMPLE_RATE = 16_000
    }
}
