// Adapted from ClosePaw PostActionAnalysis.kt and UiChangeDetector.kt.
// Copyright 2026 ClosePaw Authors. Apache-2.0; see assets/licenses/closepaw-*.txt.
// Modified for SAAR: Dart accessibility trees; no screenshot fallback. Missing
// or empty observations remain unverifiable. Retries capture only, never actions.
import 'dart:convert';

import '../models/agent_task.dart';
import '../models/ui_node.dart';
import 'credential_guard.dart';

enum ScreenChange { changed, unchanged, unverifiable }

class SettledObservation {
  final UiNode? tree;
  final ScreenChange change;
  const SettledObservation(this.tree, this.change);
}

class ScreenObserver {
  static String structuralFingerprint(AgentObservation observation) {
    final data = observation.toJson();
    // Focus changes alone do not prove navigation. Keep the full fingerprint
    // for stale-target validation; ignore focus only for outcome assessment.
    for (final element in data['elements'] as List) {
      (element as Map).remove('focused');
    }
    return jsonEncode(data);
  }

  static ScreenChange compare(AgentObservation before, UiNode? after) {
    if (after == null || before.nodes.isEmpty) return ScreenChange.unverifiable;
    final observation = AgentObservation(after);
    if (observation.nodes.isEmpty) return ScreenChange.unverifiable;
    return structuralFingerprint(before) == structuralFingerprint(observation)
        ? ScreenChange.unchanged
        : ScreenChange.changed;
  }

  static Future<SettledObservation> capture({
    required AgentObservation before,
    required Future<UiNode?> Function() read,
    required bool Function() interrupted,
    required Duration initialDelay,
    Future<void> Function(Duration)? delay,
  }) async {
    final wait = delay ?? Future<void>.delayed;
    UiNode? tree;
    var change = ScreenChange.unverifiable;
    for (final duration in [
      initialDelay,
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 1000),
    ]) {
      if (interrupted()) {
        return const SettledObservation(null, ScreenChange.unverifiable);
      }
      await wait(duration);
      if (interrupted()) {
        return const SettledObservation(null, ScreenChange.unverifiable);
      }
      try {
        tree = await read();
      } catch (_) {
        tree = null;
      }
      if (CredentialGuard.isSensitiveScreen(tree)) {
        return SettledObservation(tree, ScreenChange.unverifiable);
      }
      change = compare(before, tree);
      if (change != ScreenChange.unchanged) break;
    }
    return SettledObservation(tree, change);
  }
}
