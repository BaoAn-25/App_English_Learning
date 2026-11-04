package com.example.thpt_english

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.provider.MediaStore
import android.speech.RecognizerIntent
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.thpt_english/deeplink"
    private val MEDIA_CHANNEL = "com.example.thpt_english/native_media"
    private val REQ_SPEECH = 9001
    private val REQ_CAMERA = 9002
    private val REQ_GALLERY = 9003

    private var methodChannel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null
    private var pendingMediaResult: MethodChannel.Result? = null
    private var initialDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeSpeech" -> {
                        val lang = call.argument<String>("locale") ?: "en-US"
                        val prompt = call.argument<String>("prompt") ?: "Hãy nói câu cần dịch..."
                        try {
                            pendingMediaResult = result
                            val speechIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                putExtra(
                                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                                )
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                                putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                            }
                            startActivityForResult(speechIntent, REQ_SPEECH)
                        } catch (e: Exception) {
                            pendingMediaResult = null
                            result.error("SPEECH_UNAVAILABLE", e.message, null)
                        }
                    }
                    "pickImageBase64" -> {
                        val source = call.argument<String>("source") ?: "gallery"
                        try {
                            pendingMediaResult = result
                            if (source == "camera") {
                                val camIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                                startActivityForResult(camIntent, REQ_CAMERA)
                            } else {
                                val pickIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                    type = "image/*"
                                }
                                startActivityForResult(
                                    Intent.createChooser(pickIntent, "Chọn ảnh trang sách / bài tập"),
                                    REQ_GALLERY
                                )
                            }
                        } catch (e: Exception) {
                            pendingMediaResult = null
                            result.error("IMAGE_PICK_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val callback = pendingMediaResult ?: return

        if (requestCode == REQ_SPEECH) {
            pendingMediaResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = if (!matches.isNullOrEmpty()) matches[0] else ""
                callback.success(spokenText)
            } else {
                callback.success("")
            }
            return
        }

        if (requestCode == REQ_CAMERA) {
            pendingMediaResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                try {
                    @Suppress("DEPRECATION")
                    val bitmap = data.extras?.get("data") as? Bitmap
                    if (bitmap != null) {
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                        val base64Str = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
                        callback.success(base64Str)
                        return
                    }
                } catch (_: Exception) {}
            }
            callback.success("")
            return
        }

        if (requestCode == REQ_GALLERY) {
            pendingMediaResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val inputStream = contentResolver.openInputStream(uri)
                    val bytes = inputStream?.readBytes()
                    inputStream?.close()
                    if (bytes != null && bytes.isNotEmpty()) {
                        val base64Str = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        callback.success(base64Str)
                        return
                    }
                } catch (_: Exception) {}
            }
            callback.success("")
            return
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val uri = intent.dataString
        if (uri != null) {
            methodChannel?.invokeMethod("onDeepLink", uri)
        }
    }
}
