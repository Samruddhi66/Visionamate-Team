package com.visionmate.visionmate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.visionmate.visionmate/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "getApkPath") {
                try {
                    val apkPath = applicationContext.applicationInfo.sourceDir
                    result.success(apkPath)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Cannot get APK path", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
