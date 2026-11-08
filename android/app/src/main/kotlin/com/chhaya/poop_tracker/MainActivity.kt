package com.chhaya.poop_tracker

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by local_auth for the system
 * biometric / device-credential prompt.
 *
 * The "morrow/privacy" channel lets the app hide its recent-apps thumbnail
 * while app lock is on (Android 13+). Screenshots stay allowed: no
 * FLAG_SECURE.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "morrow/privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setRecentsPreviewHidden" -> {
                        val hidden = call.arguments as? Boolean ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(!hidden)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
