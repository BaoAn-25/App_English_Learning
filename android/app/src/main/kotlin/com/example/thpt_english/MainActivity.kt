package com.example.thpt_english

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.thpt_english/deeplink"
    private var methodChannel: MethodChannel? = null
    private var initialDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Lưu URI nếu app khởi động lần đầu từ Deep Link
        if (intent?.dataString != null) {
            initialDeepLink = intent.dataString
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialDeepLink") {
                    val link = initialDeepLink
                    initialDeepLink = null
                    result.success(link)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Khi app đang chạy ngầm và được mở lại từ Deep Link trên trình duyệt
        val uri = intent.dataString
        if (uri != null) {
            methodChannel?.invokeMethod("onDeepLink", uri)
        }
    }
}
