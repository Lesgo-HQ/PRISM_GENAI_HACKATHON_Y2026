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

        // Sensitive field detection patterns
        private val SENSITIVE_RESOURCE_PATTERNS = listOf(
            "password", "passwd", "otp", "pin", "cvv",
            "card_number", "credit_card", "debit_card",
            "security_code", "card_num", "expiry", "cvc",
            "mpin", "secret", "ssn"
        )

        private val SENSITIVE_DESCRIPTION_PATTERNS = listOf(
            "password", "otp", "pin", "cvv", "card number",
            "security code", "verification code", "credit card",
            "debit card", "enter otp", "enter pin", "enter cvv",
            "enter password", "verify otp", "mpin"
        )

        private val PASSWORD_INPUT_TYPE_VARIATIONS = listOf(
            InputType.TYPE_TEXT_VARIATION_PASSWORD,           // 0x80
            InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,   // 0x90
            InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,       // 0xE0
            InputType.TYPE_NUMBER_VARIATION_PASSWORD          // 0x10
        )

        fun getLatestTreeJson(): String? = latestTreeJson

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

        fun isTeachModeEnabled(): Boolean = teachModeEnabled

        fun setTeachMode(enabled: Boolean) {
            teachModeEnabled = enabled
            if (enabled) {
                synchronized(actionTraceLock) {
                    actionTrace.clear()
                }
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
         * Deterministic credential/sensitive-screen guard.
         * Scans the entire current UI tree for password/OTP/payment indicators.
         * FAIL-CLOSED: returns true (sensitive detected) on any error.
         */
        fun isSensitiveScreenDetected(): Boolean {
            return try {
                val svc = instance ?: return true // fail-closed: no service = block
                val rootNode = svc.rootInActiveWindow ?: return true // fail-closed
                val result = checkNodeTreeForSensitive(rootNode)
                rootNode.recycle()
                result
            } catch (e: Exception) {
                Log.e(TAG, "Credential guard error (fail-closed): ${e.message}")
                true // fail-closed
            }
        }

        private fun checkNodeTreeForSensitive(node: AccessibilityNodeInfo): Boolean {
            try {
                if (isNodeSensitive(node)) return true
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i) ?: continue
                    try {
                        if (checkNodeTreeForSensitive(child)) return true
                    } finally {
                        child.recycle()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error scanning node tree (fail-closed): ${e.message}")
                return true // fail-closed on scan error
            }
            return false
        }

        private fun isNodeSensitive(node: AccessibilityNodeInfo): Boolean {
            // 1. Check isPassword flag directly
            if (node.isPassword) return true

            // 2. Check inputType for password variations
            val inputType = node.inputType
            if (inputType != 0) {
                val variation = inputType and 0xFF0
                if (PASSWORD_INPUT_TYPE_VARIATIONS.any { (inputType and it) == it || variation == it }) {
                    return true
                }
                // Also check TYPE_CLASS_NUMBER with password variation
                if ((inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_NUMBER &&
                    (inputType and InputType.TYPE_NUMBER_VARIATION_PASSWORD) == InputType.TYPE_NUMBER_VARIATION_PASSWORD) {
                    return true
                }
            }

            // 3. Check resourceId (viewIdResourceName)
            val resourceId = node.viewIdResourceName?.lowercase() ?: ""
            if (SENSITIVE_RESOURCE_PATTERNS.any { resourceId.contains(it) }) return true

            // 4. Check className
            val className = node.className?.toString()?.lowercase() ?: ""
            if (className.contains("password")) return true

            // 5. Check contentDescription
            val contentDesc = node.contentDescription?.toString()?.lowercase() ?: ""
            if (SENSITIVE_DESCRIPTION_PATTERNS.any { contentDesc.contains(it) }) return true

            // 6. Check text for login/OTP prompts
            val text = node.text?.toString()?.lowercase() ?: ""
            val loginTextPatterns = listOf(
                "enter otp", "enter pin", "enter cvv", "enter password",
                "verify otp", "verification code", "enter mpin"
            )
            if (loginTextPatterns.any { text.contains(it) }) return true

            // 7. Check hintText
            val hintText = node.hintText?.toString()?.lowercase() ?: ""
            if (SENSITIVE_RESOURCE_PATTERNS.any { hintText.contains(it) }) return true

            return false
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
        instance = null
        Log.i(TAG, "SaarAccessibilityService destroyed")
        super.onDestroy()
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
}

