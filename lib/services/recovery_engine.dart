import '../models/ui_node.dart';
import 'accessibility_bridge.dart';

enum RecoveryAction {
  refreshed,
  dismissedPopup,
  scrolled,
  backPressed,
  wrongPackage,
  unavailable,
}

class RecoveryResult {
  final RecoveryAction action;
  final UiNode? tree;

  const RecoveryResult(this.action, this.tree);
  bool get recovered =>
      action != RecoveryAction.unavailable &&
      action != RecoveryAction.wrongPackage;
}

class RecoveryEngine {
  final AccessibilityBridge _bridge;
  String? _expectedPackage;
  int _consecutiveFailures = 0;

  RecoveryEngine(this._bridge);

  void setExpectedPackage(String packageName) {
    _expectedPackage = packageName;
    _consecutiveFailures = 0;
  }

  Future<RecoveryResult> recover(UiNode tree) async {
    _consecutiveFailures++;
    final refreshed = await _bridge.getLastTree();
    final current = refreshed ?? tree;

    // Detect wrong package
    if (_expectedPackage != null &&
        current.packageName != null &&
        current.packageName != _expectedPackage) {
      return RecoveryResult(RecoveryAction.wrongPackage, current);
    }

    if (await _dismissSafePopup(current)) {
      _consecutiveFailures = 0;
      return RecoveryResult(
        RecoveryAction.dismissedPopup,
        await _bridge.getLastTree(),
      );
    }

    if (await _scroll(current)) {
      _consecutiveFailures = 0;
      return RecoveryResult(
        RecoveryAction.scrolled,
        await _bridge.getLastTree(),
      );
    }

    // After multiple failures, try pressing back to escape a wrong screen
    if (_consecutiveFailures > 2) {
      if (await _bridge.performGlobalAction(
        AccessibilityBridge.globalActionBack,
      )) {
        _consecutiveFailures = 0;
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        return RecoveryResult(
          RecoveryAction.backPressed,
          await _bridge.getLastTree(),
        );
      }
    }

    return refreshed == null
        ? const RecoveryResult(RecoveryAction.unavailable, null)
        : RecoveryResult(RecoveryAction.refreshed, refreshed);
  }

  Future<bool> _dismissSafePopup(UiNode tree) async {
    const safe = {
      'ok',
      'close',
      'dismiss',
      'not now',
      'skip',
      'later',
      'no thanks',
      'got it',
    };
    const blocked = {
      'pay',
      'purchase',
      'place order',
      'delete',
      'remove account',
      'transfer',
      'send money',
      'confirm purchase',
      'transfer funds',
      'authorize',
      'confirm payment',
    };
    for (final node in tree.flatten()) {
      final label = '${node.text ?? ''} ${node.contentDescription ?? ''}'
          .toLowerCase()
          .trim();
      if (!node.isClickable || blocked.any(label.contains)) continue;

      bool isSafe = false;
      for (final s in safe) {
        if (label == s || label.startsWith('$s ')) {
          isSafe = true;
          break;
        }
      }

      if (!isSafe) continue;

      final bounds = node.bounds;
      return _bridge.tap(
        ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2,
        ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2,
      );
    }
    return false;
  }

  Future<bool> _scroll(UiNode tree) async {
    for (final node in tree.flatten()) {
      if (!node.isScrollable) continue;
      final bounds = node.bounds;
      final x = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2;
      final y = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2;
      return _bridge.swipe(x, y + 300, x, y - 300, durationMs: 300);
    }
    return false;
  }
}
