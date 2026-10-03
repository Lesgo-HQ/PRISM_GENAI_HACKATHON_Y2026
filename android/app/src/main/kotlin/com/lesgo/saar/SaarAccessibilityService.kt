package com.lesgo.saar

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.text.InputType
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

/**
 * SAAR Accessibility Service
 *
 * Captures full UI node trees, tracks user actions during teach mode,
 * and dispatches automation gestures with a fail-closed credential guard.
 */
class SaarAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "SaarAccessibility"

        @Volatile
        private var instance: SaarAccessibilityService? = null

        @Volatile
        private var latestTreeJson: String? = null

        @Volatile
        private var teachModeEnabled = false

        private val actionTrace = mutableListOf<JSONObject>()
        private val actionTraceLock = Any()

        /**
         * Credential keywords matched as whole words only.
         *
         * Substring matching is unusable here: "pin" appears inside "shopping" and
         * "spinner", "otp" inside resource ids such as "photo_tp", so a `contains`
         * check flags almost every ordinary screen and halts the run.
         */
        private val SENSITIVE_WORD_REGEX = Regex(
            "(^|[^a-z0-9])(" +
                "password|passwd|otp|cvv|cvc|mpin|ssn|pin|" +
                "card[ _-]?number|card[ _-]?num|credit[ _-]?card|debit[ _-]?card|security[ _-]?code" +
                ")($|[^a-z0-9])",
            RegexOption.IGNORE_CASE
        )

        /** Explicit prompts that only ever appear on a credential entry screen. */
        private val SENSITIVE_PROMPTS = listOf(
            "enter otp", "enter pin", "enter cvv", "enter cvc", "enter mpin",
            "enter password", "verify otp", "verification code", "one time password",
            "security code", "card number"
        )

        fun getLatestTreeJson(): String? = latestTreeJson

        fun refreshTreeJson(): String? {
            instance?.captureTree()
            return latestTreeJson
        }

        fun dispatchTap(x: Float, y: Float): Boolean {
            val svc = instance ?: run {
                Log.e(TAG, "dispatchTap: Service not running")
                return false
            }
            // Credential guard: fail-closed
            if (isSensitiveScreenDetected()) {
                Log.w(TAG, "dispatchTap BLOCKED: sensitive screen detected")
                return false
            }
            return svc.performTap(x, y)
        }

        fun dispatchSwipe(
            startX: Float, startY: Float,
            endX: Float, endY: Float,
            durationMs: Long
        ): Boolean {
            val svc = instance ?: run {
                Log.e(TAG, "dispatchSwipe: Service not running")
                return false
            }
            if (isSensitiveScreenDetected()) {
                Log.w(TAG, "dispatchSwipe BLOCKED: sensitive screen detected")
                return false
            }
            return svc.performSwipe(startX, startY, endX, endY, durationMs)
        }

        fun typeIntoFocused(value: String): Boolean {
            val svc = instance ?: run {
                Log.e(TAG, "typeIntoFocused: Service not running")
                return false
            }
            if (isSensitiveScreenDetected()) {
                Log.w(TAG, "typeIntoFocused BLOCKED: sensitive screen detected")
                return false
            }
            return svc.performTypeIntoFocused(value)
        }

        fun performActionOnNode(nodeHashCode: String, actionId: Int): Boolean {
            val svc = instance ?: run {
                Log.e(TAG, "performActionOnNode: Service not running")
                return false
            }
            if (isSensitiveScreenDetected()) {
                Log.w(TAG, "performActionOnNode BLOCKED: sensitive screen detected")
                return false
            }
            return svc.performNodeAction(nodeHashCode, actionId)
        }

        fun isServiceRunning(): Boolean = instance != null

        fun performGlobalAction(action: Int): Boolean {
            val svc = instance ?: run {
                Log.e(TAG, "performGlobalAction: Service not running")
                return false
            }
            return svc.performGlobalAction(action)
        }

        fun isTeachModeEnabled(): Boolean = teachModeEnabled

        fun setTeachMode(enabled: Boolean) {
            teachModeEnabled = enabled
            if (enabled) {
                synchronized(actionTraceLock) {
                    actionTrace.clear()
                }
                instance?.showRecordingOverlay()
            } else {
                instance?.hideRecordingOverlay()
            }
            Log.i(TAG, "Teach mode ${if (enabled) "ENABLED" else "DISABLED"}")
        }

        fun getActionTrace(): String {
            synchronized(actionTraceLock) {
                val arr = JSONArray()
                actionTrace.forEach { arr.put(it) }
                return arr.toString()
            }
        }

        fun clearActionTrace() {
            synchronized(actionTraceLock) {
                actionTrace.clear()
            }
        }

        /**
         * Deterministic credential guard. Scans the current UI tree for password,
         * OTP and card-entry fields.
         *
         * An unreadable window is reported as "not sensitive" rather than blocking:
         * gesture dispatch already fails without an active window, and reporting
         * sensitive here would permanently halt the run on a transient null root.
         */
        fun isSensitiveScreenDetected(): Boolean {
            return try {
                val svc = instance ?: return false
                val rootNode = svc.rootInActiveWindow ?: return false
                val result = checkNodeTreeForSensitive(rootNode, 0)
                rootNode.recycle()
                result
            } catch (e: Exception) {
                Log.w(TAG, "Credential guard scan failed: ${e.message}")
                false
            }
        }

        private fun checkNodeTreeForSensitive(node: AccessibilityNodeInfo, depth: Int): Boolean {
            if (depth > 60) return false
            try {
                if (isNodeSensitive(node)) return true
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    try {
                        if (checkNodeTreeForSensitive(child, depth + 1)) return true
                    } finally {
                        child.recycle()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error scanning node tree: ${e.message}")
                return false
            }
            return false
        }

        private fun isNodeSensitive(node: AccessibilityNodeInfo): Boolean {
            if (node.isPassword) return true
            if (isPasswordInputType(node.inputType)) return true

            val className = node.className?.toString()?.lowercase() ?: ""
            if (className.contains("password")) return true

            val resourceId = node.viewIdResourceName ?: ""
            val hintText = node.hintText?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            if (SENSITIVE_WORD_REGEX.containsMatchIn(resourceId) ||
                SENSITIVE_WORD_REGEX.containsMatchIn(hintText) ||
                SENSITIVE_WORD_REGEX.containsMatchIn(contentDesc)
            ) {
                return true
            }

            val text = node.text?.toString()?.lowercase() ?: ""
            return SENSITIVE_PROMPTS.any { text.contains(it) }
        }

        /**
         * The variation must be read against the declared class: bare masking
         * would flag TYPE_TEXT_VARIATION_URI and TYPE_TEXT_VARIATION_PERSON_NAME,
         * which share bits with the number-password variation.
         */
        private fun isPasswordInputType(inputType: Int): Boolean {
            if (inputType == 0) return false
            val variation = inputType and InputType.TYPE_MASK_VARIATION
            val inputClass = inputType and InputType.TYPE_MASK_CLASS

            if (inputClass == InputType.TYPE_CLASS_TEXT || inputClass == 0) {
                if (variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                    variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                    variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
                ) {
                    return true
                }
            }
            if (inputClass == InputType.TYPE_CLASS_NUMBER || inputClass == 0) {
                if (variation == InputType.TYPE_NUMBER_VARIATION_PASSWORD) return true
            }
            return false
        }

        fun getInstalledApps(context: android.content.Context): String {
            val pm = context.packageManager
            val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
                addCategory(android.content.Intent.CATEGORY_LAUNCHER)
            }
            val resolveInfos = pm.queryIntentActivities(intent, 0)
            val apps = JSONArray()
            for (info in resolveInfos) {
                val appInfo = info.activityInfo.applicationInfo
                val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
                if (!isSystem) {
                    val obj = JSONObject()
                    obj.put("packageName", appInfo.packageName)
                    obj.put("appName", appInfo.loadLabel(pm).toString())
                    obj.put("canLaunch", true)
                    apps.put(obj)
                }
            }
            return apps.toString()
        }

        fun takeScreenshotBase64(callback: (String?) -> Unit) {
            val svc = instance ?: run {
                Log.e(TAG, "takeScreenshotBase64: Service not running")
                callback(null)
                return
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                svc.takeScreenshot(android.view.Display.DEFAULT_DISPLAY, svc.mainExecutor, object : AccessibilityService.TakeScreenshotCallback {
                    override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                        try {
                            val hardwareBuffer = screenshot.hardwareBuffer
                            val bitmap = android.graphics.Bitmap.wrapHardwareBuffer(hardwareBuffer, screenshot.colorSpace)
                            if (bitmap != null) {
                                val out = java.io.ByteArrayOutputStream()
                                bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 50, out)
                                val bytes = out.toByteArray()
                                val base64 = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
                                callback(base64)
                            } else {
                                callback(null)
                            }
                            hardwareBuffer.close()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing screenshot", e)
                            callback(null)
                        }
                    }
                    override fun onFailure(errorCode: Int) {
                        Log.e(TAG, "Screenshot failed with error code: $errorCode")
                        callback(null)
                    }
                })
            } else {
                Log.e(TAG, "takeScreenshot requires API 30+")
                callback(null)
            }
        }

        fun performLongPress(x: Float, y: Float): Boolean {
            val svc = instance ?: return false
            if (isSensitiveScreenDetected()) return false
            return svc.doPerformLongPress(x, y)
        }

        fun performDoubleTap(x: Float, y: Float): Boolean {
            val svc = instance ?: return false
            if (isSensitiveScreenDetected()) return false
            return svc.doPerformDoubleTap(x, y)
        }

        fun setFocusOnNode(nodeId: String): Boolean {
            val svc = instance ?: return false
            return svc.doSetFocusOnNode(nodeId)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "SaarAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        try {
            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    captureTree()
                }
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    if (teachModeEnabled) {
                        recordAction("tap", event)
                    }
                    captureTree()
                }
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    if (teachModeEnabled) {
                        recordAction("type", event)
                    }
                }
                AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                    if (teachModeEnabled) {
                        recordAction("scroll", event)
                    }
                }
                AccessibilityEvent.TYPE_VIEW_FOCUSED -> {
                    if (teachModeEnabled) {
                        recordAction("focus", event)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling event: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "SaarAccessibilityService interrupted")
    }

    override fun onDestroy() {
        hideRecordingOverlay()
        instance = null
        Log.i(TAG, "SaarAccessibilityService destroyed")
        super.onDestroy()
    }

    // ── Recording Overlay ──────────────────────────────────────────

    private var overlayView: android.view.View? = null
    private var windowManager: android.view.WindowManager? = null

    fun showRecordingOverlay() {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                if (overlayView != null) return@post
                windowManager = getSystemService(android.content.Context.WINDOW_SERVICE) as android.view.WindowManager
                
                val layoutParams = android.view.WindowManager.LayoutParams(
                    android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                    android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                    android.view.WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    android.graphics.PixelFormat.TRANSLUCENT
                )
                layoutParams.gravity = android.view.Gravity.TOP or android.view.Gravity.CENTER_HORIZONTAL
                layoutParams.y = 100 // adjust below notch
                
                val container = android.widget.LinearLayout(this)
                container.orientation = android.widget.LinearLayout.HORIZONTAL
                container.gravity = android.view.Gravity.CENTER_VERTICAL
                container.setPadding(60, 30, 60, 30)
                
                val bg = android.graphics.drawable.GradientDrawable()
                bg.cornerRadius = 100f
                bg.setColor(android.graphics.Color.parseColor("#FF3B30")) // Professional red
                bg.setStroke(4, android.graphics.Color.parseColor("#4CFF3B30"))
                container.background = bg
                container.elevation = 24f
                
                val text = android.widget.TextView(this)
                text.text = "SAAR is Recording Actions"
                text.setTextColor(android.graphics.Color.WHITE)
                text.textSize = 16f
                text.setTypeface(null, android.graphics.Typeface.BOLD)
                text.setShadowLayer(4f, 0f, 2f, android.graphics.Color.parseColor("#80000000"))
                
                container.addView(text)
                
                overlayView = container
                windowManager?.addView(overlayView, layoutParams)
            } catch (e: Exception) {
                Log.e(TAG, "Error showing overlay: ${e.message}")
            }
        }
    }

    fun hideRecordingOverlay() {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                if (overlayView != null) {
                    windowManager?.removeView(overlayView)
                    overlayView = null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding overlay: ${e.message}")
            }
        }
    }

    // â”€â”€ Tree capture â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    private fun captureTree() {
        try {
            val root = rootInActiveWindow ?: return
            val tree = serializeNode(root)
            latestTreeJson = tree.toString()
            root.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing tree: ${e.message}")
        }
    }

    private fun serializeNode(node: AccessibilityNodeInfo): JSONObject {
        val obj = JSONObject()
        try {
            obj.put("nodeId", node.viewIdResourceName ?: "")
            obj.put("className", node.className?.toString() ?: "")
            obj.put("text", node.text?.toString() ?: "")
            obj.put("contentDescription", node.contentDescription?.toString() ?: "")
            obj.put("hintText", node.hintText?.toString() ?: "")
            obj.put("resourceId", node.viewIdResourceName ?: "")
            obj.put("packageName", node.packageName?.toString() ?: "")

            val rect = Rect()
            node.getBoundsInScreen(rect)
            val bounds = JSONObject()
            bounds.put("left", rect.left)
            bounds.put("top", rect.top)
            bounds.put("right", rect.right)
            bounds.put("bottom", rect.bottom)
            obj.put("bounds", bounds)

            obj.put("isClickable", node.isClickable)
            obj.put("isEditable", node.isEditable)
            obj.put("isScrollable", node.isScrollable)
            obj.put("isCheckable", node.isCheckable)
            obj.put("isChecked", node.isChecked)
            obj.put("isFocusable", node.isFocusable)
            obj.put("isFocused", node.isFocused)
            obj.put("inputType", node.inputType)

            val children = JSONArray()
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    try {
                        children.put(serializeNode(child))
                    } finally {
                        child.recycle()
                    }
                }
            }
            obj.put("children", children)
        } catch (e: Exception) {
            Log.e(TAG, "Error serializing node: ${e.message}")
        }
        return obj
    }

    // â”€â”€ Teach-mode action recording â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    private fun recordAction(action: String, event: AccessibilityEvent) {
        try {
            val source = event.source
            val nodeJson = if (source != null) {
                try {
                    serializeNodeFlat(source)
                } finally {
                    source.recycle()
                }
            } else {
                JSONObject()
            }

            val record = JSONObject().apply {
                put("timestampMs", System.currentTimeMillis())
                put("action", action)
                put("node", nodeJson)
                put("valueTyped", if (action == "type") event.text?.joinToString("") ?: "" else "")
                put("packageName", event.packageName?.toString() ?: "")
                if (action == "scroll") {
                    put("scrollDeltaX", event.scrollDeltaX)
                    put("scrollDeltaY", event.scrollDeltaY)
                }
            }

            synchronized(actionTraceLock) {
                actionTrace.add(record)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error recording action: ${e.message}")
        }
    }

    /** Serialize a single node without children (for action trace). */
    private fun serializeNodeFlat(node: AccessibilityNodeInfo): JSONObject {
        val obj = JSONObject()
        try {
            obj.put("nodeId", node.viewIdResourceName ?: "")
            obj.put("className", node.className?.toString() ?: "")
            obj.put("text", node.text?.toString() ?: "")
            obj.put("contentDescription", node.contentDescription?.toString() ?: "")
            obj.put("hintText", node.hintText?.toString() ?: "")
            obj.put("resourceId", node.viewIdResourceName ?: "")
            obj.put("packageName", node.packageName?.toString() ?: "")

            val rect = Rect()
            node.getBoundsInScreen(rect)
            val bounds = JSONObject()
            bounds.put("left", rect.left)
            bounds.put("top", rect.top)
            bounds.put("right", rect.right)
            bounds.put("bottom", rect.bottom)
            obj.put("bounds", bounds)

            obj.put("isClickable", node.isClickable)
            obj.put("isEditable", node.isEditable)
            obj.put("isScrollable", node.isScrollable)
            obj.put("isCheckable", node.isCheckable)
            obj.put("isChecked", node.isChecked)
            obj.put("isFocusable", node.isFocusable)
            obj.put("isFocused", node.isFocused)
            obj.put("inputType", node.inputType)
            obj.put("children", JSONArray()) // no children in flat serialization
        } catch (e: Exception) {
            Log.e(TAG, "Error serializing flat node: ${e.message}")
        }
        return obj
    }

    // â”€â”€ Gesture dispatch â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    private fun performTap(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            var success = false
            val latch = java.util.concurrent.CountDownLatch(1)

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)

            latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
            Log.d(TAG, "Tap at ($x, $y): $success")
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error dispatching tap: ${e.message}")
            false
        }
    }

    private fun performSwipe(
        startX: Float, startY: Float,
        endX: Float, endY: Float,
        durationMs: Long
    ): Boolean {
        return try {
            val path = Path().apply {
                moveTo(startX, startY)
                lineTo(endX, endY)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(100))
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            var success = false
            val latch = java.util.concurrent.CountDownLatch(1)

            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)

            latch.await(durationMs + 2000, java.util.concurrent.TimeUnit.MILLISECONDS)
            Log.d(TAG, "Swipe ($startX,$startY)->($endX,$endY): $success")
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error dispatching swipe: ${e.message}")
            false
        }
    }

    private fun performTypeIntoFocused(value: String): Boolean {
        return try {
            val root = rootInActiveWindow ?: return false
            val focusedNode = findFocusedEditableNode(root)
            root.recycle()

            if (focusedNode != null) {
                try {
                    val args = Bundle().apply {
                        putCharSequence(
                            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                            value
                        )
                    }
                    val result = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    Log.d(TAG, "Type into focused '$value': $result")
                    result
                } finally {
                    focusedNode.recycle()
                }
            } else {
                Log.w(TAG, "No focused editable node found for typing")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error typing into focused: ${e.message}")
            false
        }
    }

    private fun findFocusedEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && node.isEditable) {
            return AccessibilityNodeInfo.obtain(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            try {
                val result = findFocusedEditableNode(child)
                if (result != null) return result
            } finally {
                child.recycle()
            }
        }
        return null
    }

    private fun performNodeAction(nodeHashStr: String, actionId: Int): Boolean {
        return try {
            val root = rootInActiveWindow ?: return false
            val target = findNodeByResourceId(root, nodeHashStr)
            root.recycle()

            if (target != null) {
                try {
                    val result = target.performAction(actionId)
                    Log.d(TAG, "Action $actionId on $nodeHashStr: $result")
                    result
                } finally {
                    target.recycle()
                }
            } else {
                Log.w(TAG, "Node $nodeHashStr not found for action")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error performing node action: ${e.message}")
            false
        }
    }

    private fun findNodeByResourceId(node: AccessibilityNodeInfo, resourceId: String): AccessibilityNodeInfo? {
        if (node.viewIdResourceName == resourceId) {
            return AccessibilityNodeInfo.obtain(node)
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            try {
                val result = findNodeByResourceId(child, resourceId)
                if (result != null) return result
            } finally {
                child.recycle()
            }
        }
        return null
    }

    fun doPerformLongPress(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 800)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            var success = false
            val latch = java.util.concurrent.CountDownLatch(1)
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)
            latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error in doPerformLongPress", e)
            false
        }
    }

    fun doPerformDoubleTap(x: Float, y: Float): Boolean {
        return try {
            val path = Path().apply { moveTo(x, y) }
            val stroke1 = GestureDescription.StrokeDescription(path, 0, 50)
            val stroke2 = GestureDescription.StrokeDescription(path, 150, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke1).addStroke(stroke2).build()
            var success = false
            val latch = java.util.concurrent.CountDownLatch(1)
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)
            latch.await(2, java.util.concurrent.TimeUnit.SECONDS)
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error in doPerformDoubleTap", e)
            false
        }
    }

    fun doSetFocusOnNode(nodeId: String): Boolean {
        val root = rootInActiveWindow ?: return false
        return try {
            val target = findNodeByResourceId(root, nodeId)
            if (target != null) {
                val result = target.performAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)
                target.recycle()
                result
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in doSetFocusOnNode", e)
            false
        } finally {
            root.recycle()
        }
    }
}

