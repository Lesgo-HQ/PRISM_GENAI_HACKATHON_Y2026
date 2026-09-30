package com.lesgo.saar

import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "SaarMainActivity"
        private const val METHOD_CHANNEL = "saar/accessibility"
        private const val EVENT_CHANNEL = "saar/accessibility_events"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var nluEngine: LocalNluEngine? = null
    private var teachPollHandler: Handler? = null
    private var teachPollRunnable: Runnable? = null
    private var lastTraceSentCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            val modelFile = java.io.File(filesDir, "saar_nlu.onnx")
            val dataFile = java.io.File(filesDir, "saar_nlu.onnx.data")
            assets.open("models/saar_nlu.onnx").use { input -> java.io.FileOutputStream(modelFile).use { output -> input.copyTo(output) } }
            try { assets.open("models/saar_nlu.onnx.data").use { input -> java.io.FileOutputStream(dataFile).use { output -> input.copyTo(output) } } } catch (e: Exception) {}
            nluEngine = LocalNluEngine(modelFile.absolutePath)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load ONNX model: ${e.message}", e)
        }

        // â”€â”€ MethodChannel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "openAccessibilitySettings" -> {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        }

                        "isServiceEnabled" -> {
                            result.success(isAccessibilityServiceEnabled())
                        }

                        "openApp" -> {
                            val requestedPackage = call.argument<String>("packageName")?.trim()
                            val packageName = resolveLearnedPackage(requestedPackage)
                            if (packageName.isNullOrBlank()) {
                                result.success(false)
                            } else {
                                // Do not gate this on queryIntentActivities: Android package
                                // visibility can hide an installed app from that query.
                                val launchIntent = when (packageName) {
                                    // Swiggy exposes several launcher aliases; on this
                                    // device getLaunchIntentForPackage selects a disabled
                                    // HomeIcon alias instead of the real activity.
                                    "in.swiggy.android" -> Intent().setComponent(
                                        ComponentName(
                                            packageName,
                                            "$packageName.activities.HomeActivity",
                                        )
                                    )
                                    else -> packageManager.getLaunchIntentForPackage(packageName)
                                        ?: Intent(Intent.ACTION_MAIN).apply {
                                            addCategory(Intent.CATEGORY_LAUNCHER)
                                            setPackage(packageName)
                                        }
                                }
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                try {
                                    startActivity(launchIntent)
                                    Log.i(TAG, "Opened learned app $packageName")
                                    result.success(true)
                                } catch (e: Exception) {
                                    Log.e(TAG, "Could not open learned app $packageName", e)
                                    result.success(false)
                                }
                            }
                        }

                        "performGlobalAction" -> {
                            val action = call.argument<Int>("action") ?: 0
                            result.success(SaarAccessibilityService.performGlobalAction(action))
                        }

                        "getLastTree" -> {
                            val tree = SaarAccessibilityService.refreshTreeJson()
                            result.success(tree)
                        }

                        "tap" -> {
                            val x = (call.argument<Double>("x") ?: 0.0).toFloat()
                            val y = (call.argument<Double>("y") ?: 0.0).toFloat()
                            Thread {
                                val success = SaarAccessibilityService.dispatchTap(x, y)
                                Handler(Looper.getMainLooper()).post {
                                    result.success(success)
                                }
                            }.start()
                        }

                        "swipe" -> {
                            val startX = (call.argument<Double>("startX") ?: 0.0).toFloat()
                            val startY = (call.argument<Double>("startY") ?: 0.0).toFloat()
                            val endX = (call.argument<Double>("endX") ?: 0.0).toFloat()
                            val endY = (call.argument<Double>("endY") ?: 0.0).toFloat()
                            val durationMs = (call.argument<Int>("durationMs") ?: 300).toLong()
                            Thread {
                                val success = SaarAccessibilityService.dispatchSwipe(
                                    startX, startY, endX, endY, durationMs
                                )
                                Handler(Looper.getMainLooper()).post {
                                    result.success(success)
                                }
                            }.start()
                        }

                        "typeIntoFocused" -> {
                            val value = call.argument<String>("value") ?: ""
                            Thread {
                                val success = SaarAccessibilityService.typeIntoFocused(value)
                                Handler(Looper.getMainLooper()).post {
                                    result.success(success)
                                }
                            }.start()
                        }

                        "performActionOnNode" -> {
                            val nodeId = call.argument<String>("nodeId") ?: ""
                            val actionId = call.argument<Int>("actionId")
                                ?: call.argument<Int>("action") ?: 0
                            Thread {
                                val success = SaarAccessibilityService.performActionOnNode(nodeId, actionId)
                                Handler(Looper.getMainLooper()).post {
                                    result.success(success)
                                }
                            }.start()
                        }

                        "isRecording" -> {
                            result.success(SaarAccessibilityService.isTeachModeEnabled())
                        }

                        "startTeachSession" -> {
                            stopTeachPolling()
                            SaarAccessibilityService.setTeachMode(true)
                            lastTraceSentCount = 0
                            startTeachPolling()
                            result.success(true)
                        }

                        "stopTeachSession" -> {
                            stopTeachPolling()
                            SaarAccessibilityService.setTeachMode(false)
                            val trace = SaarAccessibilityService.getActionTrace()
                            SaarAccessibilityService.clearActionTrace()
                            Log.i(TAG, "Teach session stopped with ${org.json.JSONArray(trace).length()} events")
                            result.success(trace)
                        }

                        "predictIntent" -> {
                            val inputIds = call.argument<List<Double>>("inputIds")?.map { it.toLong() }?.toLongArray() ?: longArrayOf()
                            val mask = call.argument<List<Double>>("attentionMask")?.map { it.toLong() }?.toLongArray() ?: longArrayOf()
                            Thread {
                                try {
                                    val logits = nluEngine?.parse(inputIds, mask)
                                    Handler(Looper.getMainLooper()).post {
                                        result.success(logits?.toList())
                                    }
                                } catch (e: Exception) {
                                    Handler(Looper.getMainLooper()).post {
                                        result.error("ONNX_ERROR", e.message, null)
                                    }
                                }
                            }.start()
                        }

                        "isSensitiveScreen" -> {
                            result.success(SaarAccessibilityService.isSensitiveScreenDetected())
                        }

                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "MethodChannel error: ${e.message}", e)
                    result.error("NATIVE_ERROR", e.message, e.stackTraceToString())
                }
            }

        // â”€â”€ EventChannel for teach-mode streaming â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "EventChannel: listener attached")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "EventChannel: listener cancelled")
                }
            })
    }

    /**
     * Check if our AccessibilityService is enabled in system settings.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        if (!SaarAccessibilityService.isServiceRunning()) return false
        val serviceName = "$packageName/${SaarAccessibilityService::class.java.canonicalName}"
        return try {
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (enabledServices.isNullOrEmpty()) return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)
            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                if (componentName.equals(serviceName, ignoreCase = true)) {
                    return true
                }
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accessibility service: ${e.message}")
            false
        }
    }

    private fun resolveLearnedPackage(requested: String?): String? {
        if (requested.isNullOrBlank()) return null
        val value = requested.lowercase()
        val aliases = mapOf(
            "swiggy" to "in.swiggy.android",
            "zepto" to "com.zeptoconsumerapp",
            "blinkit" to "com.grofers.customerapp",
            "zomato" to "com.application.zomato",
            "amazon" to "in.amazon.mShop.android.shopping",
            "flipkart" to "com.flipkart.android",
        )
        return aliases.entries.firstOrNull { value == it.key || value.contains(it.key) }?.value
            ?: requested
    }

    /**
     * Poll the action trace every 200ms and push new events to the EventChannel.
     */
    private fun startTeachPolling() {
        teachPollHandler = Handler(Looper.getMainLooper())
        teachPollRunnable = object : Runnable {
            override fun run() {
                try {
                    val currentTrace = SaarAccessibilityService.getActionTrace()
                    val sink = eventSink
                    if (sink != null && currentTrace.isNotEmpty()) {
                        // Parse to check count, only send if there are new events
                        val arr = org.json.JSONArray(currentTrace)
                        if (arr.length() > lastTraceSentCount) {
                            // Send only new events
                            val newEvents = org.json.JSONArray()
                            for (i in lastTraceSentCount until arr.length()) {
                                newEvents.put(arr.getJSONObject(i))
                            }
                            lastTraceSentCount = arr.length()
                            sink.success(newEvents.toString())
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Teach poll error: ${e.message}")
                }
                teachPollHandler?.postDelayed(this, 200)
            }
        }
        teachPollHandler?.postDelayed(teachPollRunnable!!, 200)
    }

    private fun stopTeachPolling() {
        teachPollRunnable?.let { teachPollHandler?.removeCallbacks(it) }
        teachPollHandler = null
        teachPollRunnable = null
        lastTraceSentCount = 0
    }

    override fun onDestroy() {
        stopTeachPolling()
        super.onDestroy()
    }
}
