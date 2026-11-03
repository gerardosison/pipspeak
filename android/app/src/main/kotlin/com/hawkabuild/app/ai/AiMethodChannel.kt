package com.hawkabuild.app.ai

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Flutter bridge for the on-device model runtimes. */
class AiMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val whisperEngine = WhisperEngine(context)
    private val poseEngine = PoseLandmarkerEngine(context)
    private val llamaEngine = LlamaEngine(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeWhisper" -> runAsync(result) {
                if (!whisperEngine.initialize()) {
                    throw IllegalStateException(whisperEngine.initializationError())
                }
                true
            }
            "transcribe" -> {
                val audioPath = call.argument<String>("audioPath").orEmpty()
                val language = call.argument<String>("language") ?: "auto"
                runAsync(result) { whisperEngine.transcribe(audioPath, language) }
            }
            "prepareQwenModel" -> runAsync(result) { llamaEngine.prepareModelFile() }
            "checkModelStatus" -> runAsync(result) {
                mapOf(
                    "whisper" to whisperEngine.initialize(),
                    "pose" to poseEngine.initialize(),
                    "llm" to llamaEngine.initialize(),
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun <T> runAsync(result: MethodChannel.Result, operation: () -> T) {
        worker.execute {
            try {
                val value = operation()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "ON_DEVICE_AI_ERROR",
                        error.message ?: "On-device AI operation failed.",
                        error.stackTraceToString(),
                    )
                }
            }
        }
    }
}
