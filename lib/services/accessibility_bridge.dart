import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ui_node.dart';
import '../models/action_trace_event.dart';

class AccessibilityBridge {
  static const _methodChannel = MethodChannel('saar/accessibility');
  static const _eventChannel = EventChannel('saar/accessibility_events');

  static const int globalActionBack = 1;
  static const int globalActionHome = 2;
  static const int globalActionRecents = 3;

  Future<bool> performGlobalAction(int action) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'performGlobalAction',
      {'action': action},
    );
    return result ?? false;
  }

  // Opens system accessibility settings
  Future<void> openAccessibilitySettings() async {
    await _methodChannel.invokeMethod('openAccessibilitySettings');
  }

  // Check if service is enabled
  Future<bool> isRecording() async {
    final result = await _methodChannel.invokeMethod<bool>('isRecording');
    return result ?? false;
  }

  Future<bool> isServiceEnabled() async {
    final result = await _methodChannel.invokeMethod<bool>('isServiceEnabled');
    return result ?? false;
  }

  Future<bool> openApp(String packageName) async {
    final result = await _methodChannel.invokeMethod<bool>('openApp', {
      'packageName': packageName,
    });
    return result ?? false;
  }

  // Get the latest UI tree
  Future<UiNode?> getLastTree() async {
    try {
      final jsonStr = await _methodChannel.invokeMethod<String>('getLastTree');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return UiNode.fromJson(decoded);
    } catch (e) {
      debugPrint('Error getting last tree: $e');
      return null;
    }
  }

  // Dispatch tap at coordinates
  Future<bool> tap(double x, double y) async {
    final result = await _methodChannel.invokeMethod<bool>('tap', {
      'x': x,
      'y': y,
    });
    return result ?? false;
  }

  // Dispatch swipe gesture
  Future<bool> swipe(
    double startX,
    double startY,
    double endX,
    double endY, {
    int durationMs = 300,
  }) async {
    final result = await _methodChannel.invokeMethod<bool>('swipe', {
      'startX': startX,
      'startY': startY,
      'endX': endX,
      'endY': endY,
      'durationMs': durationMs,
    });
    return result ?? false;
  }

  // Type text into currently focused field
  Future<bool> typeIntoFocused(String value) async {
    final result = await _methodChannel.invokeMethod<bool>('typeIntoFocused', {
      'value': value,
    });
    return result ?? false;
  }

  // Perform accessibility action on a node
  Future<bool> performActionOnNode(String nodeId, int action) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'performActionOnNode',
      {'nodeId': nodeId, 'action': action},
    );
    return result ?? false;
  }

  // Check if current screen has sensitive fields
  Future<bool> isSensitiveScreen() async {
    final result = await _methodChannel.invokeMethod<bool>('isSensitiveScreen');
    return result ?? false;
  }

  // Start the native recorder before subscribing to its event stream.
  Future<Stream<List<ActionTraceEvent>>> startTeachSession() async {
    await _methodChannel.invokeMethod<bool>('startTeachSession');
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      try {
        final decoded = event is String ? jsonDecode(event) : event;
        if (decoded is! List) return <ActionTraceEvent>[];

        // A single malformed platform event must not erase the valid events
        // that were recorded before it.
        return decoded
            .whereType<Map>()
            .map((raw) {
              try {
                return ActionTraceEvent.fromJson(
                  Map<String, dynamic>.from(raw),
                );
              } catch (e) {
                debugPrint('Skipping malformed action trace event: $e');
                return null;
              }
            })
            .whereType<ActionTraceEvent>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing action trace event stream: $e');
      }
      return <ActionTraceEvent>[];
    });
  }

  // Stop teach session - returns final action trace
  Future<List<ActionTraceEvent>> stopTeachSession() async {
    try {
      final jsonStr = await _methodChannel.invokeMethod<String>(
        'stopTeachSession',
      );
      if (jsonStr == null || jsonStr.isEmpty) return <ActionTraceEvent>[];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded
          .whereType<Map>()
          .map((raw) {
            try {
              return ActionTraceEvent.fromJson(Map<String, dynamic>.from(raw));
            } catch (e) {
              debugPrint('Skipping malformed final trace event: $e');
              return null;
            }
          })
          .whereType<ActionTraceEvent>()
          .toList();
    } catch (e) {
      debugPrint('Error stopping teach session: $e');
      return <ActionTraceEvent>[];
    }
  }
}
