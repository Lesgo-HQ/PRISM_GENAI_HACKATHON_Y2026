import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/replay_session.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/accessibility_bridge.dart';
import 'package:saar/services/clarification_service.dart';
import 'package:saar/services/replay_engine.dart';

class FakeBridge extends AccessibilityBridge {
  int taps = 0;
  bool sensitive = false;
  UiNode? tree = UiNode.fromJson({
    'packageName': 'test.shop',
    'text': 'Search',
    'isClickable': true,
    'isEditable': true,
    'bounds': {'left': 0, 'top': 0, 'right': 100, 'bottom': 50},
    'children': <dynamic>[],
  });
  @override
  Future<UiNode?> getLastTree() async => tree;
  @override
  Future<bool> isSensitiveScreen() async => sensitive;
  @override
  Future<bool> tap(double x, double y) async {
    taps++;
    return true;
  }

  @override
  Future<bool> swipe(
    double a,
    double b,
    double c,
    double d, {
    int durationMs = 300,
  }) async => false;
  @override
  Future<bool> performGlobalAction(int action) async => false;
}

class ScrollBridge extends FakeBridge {
  List<double>? gesture;
  ScrollBridge() {
    tree = UiNode.fromJson({
      'packageName': 'test.shop',
      'isScrollable': true,
      'bounds': {'left': 0, 'top': 0, 'right': 1000, 'bottom': 2000},
      'children': [],
    });
  }
  @override
  Future<bool> swipe(
    double a,
    double b,
    double c,
    double d, {
    int durationMs = 300,
  }) async {
    gesture = [a, b, c, d];
    tree = UiNode.fromJson({...tree!.toJson(), 'text': 'New visible content'});
    return true;
  }
}

Flow flow(List<FlowStep> steps) => Flow(
  flowId: 'one',
  appPackage: '',
  triggerIntent: 'search',
  exampleUtterances: [],
  slots: [],
  steps: steps,
);
void main() {
  test(
    'scroll replay preserves distance and stays within the target',
    () async {
      for (final delta in [600, 4000, -600]) {
        final bridge = ScrollBridge();
        final engine = ReplayEngine(
          bridge,
          ClarificationService(),
          stepDelay: Duration.zero,
        );
        final result = await engine.execute(
          flow([
            FlowStep(
              id: 1,
              action: 'scroll',
              targetRole: 'SCROLL_VIEW',
              scrollDeltaX: 0,
              scrollDeltaY: delta,
            ),
          ]),
          {},
        );
        expect(result.status, ReplayStatus.completed);
        final distance = delta.clamp(-1600, 1600);
        expect(bridge.gesture, [
          500,
          1000 + distance / 2,
          500,
          1000 - distance / 2,
        ]);
        engine.dispose();
      }
    },
  );
  test(
    'sensitive screen waits and can be cancelled without a gesture',
    () async {
      final bridge = FakeBridge()..sensitive = true;
      final engine = ReplayEngine(
        bridge,
        ClarificationService(),
        stepDelay: Duration.zero,
      );
      final waiting = engine.stateStream.firstWhere(
        (s) => s.status == ReplayStatus.waitingForUser,
      );
      final run = engine.execute(
        flow([FlowStep(id: 1, action: 'tap', targetRole: 'SEARCH_FIELD')]),
        {},
      );
      await waiting.timeout(const Duration(seconds: 2));
      expect(bridge.taps, 0);
      engine.stop();
      expect((await run).status, ReplayStatus.cancelled);
      engine.dispose();
    },
  );
  test(
    'unverified dispatched action is never automatically repeated',
    () async {
      final bridge = FakeBridge();
      final engine = ReplayEngine(
        bridge,
        ClarificationService(),
        stepDelay: Duration.zero,
      );
      final waiting = engine.stateStream.firstWhere(
        (s) => s.status == ReplayStatus.waitingForUser,
      );
      final run = engine.execute(
        flow([
          FlowStep(
            id: 1,
            action: 'tap',
            targetRole: 'SEARCH_FIELD',
            targetNodeText: 'Search',
            postcondition: const StepPostcondition(requiredRoles: ['CART']),
          ),
        ]),
        {},
      );
      await waiting.timeout(const Duration(seconds: 3));
      expect(bridge.taps, 1);
      engine.stop();
      await run;
      engine.dispose();
    },
  );
  test('restored uncertain action is not dispatched again', () async {
    final bridge = FakeBridge();
    final f = flow([
      FlowStep(id: 1, action: 'tap', targetRole: 'SEARCH_FIELD'),
    ]);
    final original = ReplaySession(runId: 'saved', flow: f, slots: {})
      ..actionPending = true;
    final checkpoint = ReplaySession.fromJson(original.toJson());
    final engine = ReplayEngine(
      bridge,
      ClarificationService(),
      stepDelay: Duration.zero,
    );
    final waiting = engine.stateStream.firstWhere(
      (s) => s.status == ReplayStatus.waitingForUser,
    );
    final run = engine.execute(f, {}, checkpoint: checkpoint);
    await waiting.timeout(const Duration(seconds: 2));
    expect(bridge.taps, 0);
    engine.resume(stepCompleted: true);
    expect((await run).status, ReplayStatus.completed);
    expect(bridge.taps, 0);
    engine.dispose();
  });
  test(
    'manual boundary completes only after explicit human acknowledgement',
    () async {
      final bridge = FakeBridge();
      final engine = ReplayEngine(
        bridge,
        ClarificationService(),
        stepDelay: Duration.zero,
      );
      final waiting = engine.stateStream.firstWhere(
        (s) => s.status == ReplayStatus.waitingForUser,
      );
      final run = engine.execute(
        flow([FlowStep(id: 1, action: 'stop_before', targetRole: 'PAYMENT')]),
        {},
      );
      await waiting;
      expect(bridge.taps, 0);
      engine.resume(stepCompleted: true);
      expect((await run).status, ReplayStatus.completed);
      expect(bridge.taps, 0);
      engine.dispose();
    },
  );
  test('checkpoint failure prevents gesture dispatch', () async {
    final bridge = FakeBridge();
    final engine = ReplayEngine(
      bridge,
      ClarificationService(),
      stepDelay: Duration.zero,
      saveCheckpoint: (_) async => throw StateError('disk full'),
    );
    await expectLater(
      engine.execute(
        flow([FlowStep(id: 1, action: 'tap', targetRole: 'SEARCH_FIELD')]),
        {},
      ),
      throwsStateError,
    );
    expect(bridge.taps, 0);
    engine.dispose();
  });
}
