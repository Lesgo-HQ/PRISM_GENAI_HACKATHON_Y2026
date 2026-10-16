import '../models/ui_node.dart';
import 'accessibility_bridge.dart';
import 'credential_guard.dart';

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

  RecoveryEngine(this._bridge);

  void setExpectedPackage(String packageName) {
    _expectedPackage = packageName;
  }

  Future<RecoveryResult> recover(UiNode tree, {bool Function()? isCancelled}) async {
    final refreshed = await _bridge.getLastTree();
    final current = refreshed;
    if (current == null ||
        CredentialGuard.isSensitiveScreen(current) ||
        await _bridge.isSensitiveScreen()) {
      return const RecoveryResult(RecoveryAction.unavailable, null);
    }

    // Detect wrong package
    if (_expectedPackage != null &&
        _expectedPackage!.isNotEmpty &&
        current.packageName != null &&
        current.packageName != _expectedPackage) {
      return RecoveryResult(RecoveryAction.wrongPackage, current);
    }

    if (isCancelled?.call() == true) return RecoveryResult(RecoveryAction.unavailable, current);
    if (await _dismissSafePopup(current)) {
      return RecoveryResult(
        RecoveryAction.dismissedPopup,
        await _bridge.getLastTree(),
      );
    }

    if (isCancelled?.call() == true) return RecoveryResult(RecoveryAction.unavailable, current);
    if (await _scroll(current)) {
      return RecoveryResult(
        RecoveryAction.scrolled,
        await _bridge.getLastTree(),
      );
    }

    return RecoveryResult(RecoveryAction.refreshed, refreshed);
  }

  Future<bool> _dismissSafePopup(UiNode tree) async {
    const safe = {
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
        if (label == s) {
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
