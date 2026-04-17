package com.biovolt.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.biovolt.app/widget"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        // Handle the launch intent in case the app was cold-started
        // from a widget action.
        dispatchWidgetAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchWidgetAction(intent)
    }

    private fun dispatchWidgetAction(intent: Intent?) {
        val action = intent?.action ?: return
        val channel = methodChannel ?: return
        when (action) {
            "com.biovolt.app.ACTION_VOICE_NOTE" ->
                channel.invokeMethod("openVoiceNote", null)
            "com.biovolt.app.ACTION_START_SESSION" ->
                channel.invokeMethod("openSessionLauncher", null)
        }
    }
}
