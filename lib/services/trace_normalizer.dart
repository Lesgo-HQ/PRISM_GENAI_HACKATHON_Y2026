import '../models/action_trace_event.dart';

class TraceNormalizer {
  List<ActionTraceEvent> normalize(List<ActionTraceEvent> trace) {
    const systemPackages = [
      'com.android.systemui',
      'com.android.launcher3',
      'com.google.android.apps.nexuslauncher',
      'com.android.packageinstaller',
      'com.android.permissioncontroller',
    ];

    final filtered = <ActionTraceEvent>[];

    // Sort by timestamp
    final sorted = List<ActionTraceEvent>.from(trace)
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    for (int i = 0; i < sorted.length; i++) {
      final event = sorted[i];

      // 1. Remove system package events
      if (event.packageName != null &&
          systemPackages.contains(event.packageName)) {
        continue;
      }

      // 2. Remove duplicate actions within 100ms on same node
      if (filtered.isNotEmpty) {
        final lastEvent = filtered.last;
        final timeDiff = event.timestampMs - lastEvent.timestampMs;
        final sameNode =
            event.node?.nodeId != null &&
            event.node?.nodeId == lastEvent.node?.nodeId &&
            event.node!.nodeId!.isNotEmpty;
        if (timeDiff < 100 && sameNode && event.action == lastEvent.action) {
          continue;
        }

        // Merge consecutive type events on same node
        if (sameNode && event.action == 'type' && lastEvent.action == 'type') {
          filtered.removeLast();
        }
      }

      // 3. Remove notification shade interactions
      if (event.node != null) {
        final className = (event.node!.className ?? '').toLowerCase();
        final resourceId = (event.node!.resourceId ?? '').toLowerCase();
        if (className.contains('notification') ||
            resourceId.contains('notification') ||
            resourceId.contains('status_bar') ||
            className.contains('statusbar')) {
          continue;
        }
      }

      // 4. Skip focus events that are immediately followed by a tap or type on same node
      if (event.action == 'focus' && i + 1 < sorted.length) {
        final nextEvent = sorted[i + 1];
        if ((nextEvent.action == 'tap' || nextEvent.action == 'type') &&
            nextEvent.node?.nodeId == event.node?.nodeId) {
          continue; // skip redundant focus
        }
      }

      // Detect incidental actions (basic filtering)
      if (event.action == 'incidental' || event.action == 'call_interruption') {
        continue;
      }

      filtered.add(event);
    }

    return filtered;
  }
}
