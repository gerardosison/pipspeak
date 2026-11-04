package com.hawkabuild.app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.hawkabuild.app.ai.AiMethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.hawkabuild.app/ai"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler(AiMethodChannel(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pipspeak/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", "Open PipSpeak permissions in Android Settings.", null)
                    }
                } else result.notImplemented()
            }
    }
}
