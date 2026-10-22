import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saar/models/agent_task.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/adaptive_agent.dart';
import 'package:saar/services/accessibility_bridge.dart';
import 'package:saar/services/llm_client.dart';

UiNode screen(String text) => UiNode.fromJson({
  'packageName': 'shop',
  'text': text,
  'isClickable': true,
  'isEditable': true,
  'bounds': {'left': 0, 'top': 0, 'right': 100, 'bottom': 100},
  'children': [],
});

class Device extends AccessibilityBridge {
  UiNode tree = screen('Search');
  int taps = 0;
  int opens = 0;
  @override
  Future<bool> openApp(String packageName) async {
    opens++;
    return true;
  }

  @override
  Future<UiNode?> getLastTree() async => tree;
  @override
  Future<bool> isSensitiveScreen() async => false;
  @override
  Future<bool> tap(double x, double y) async {
    taps++;
    tree = screen('Pizza results');
    return true;
  }
}

class LaunchingDevice extends Device {
  int launchReads = 0;
  bool neverReady = false;
  @override
  Future<UiNode?> getLastTree() async {
    launchReads++;
    if (neverReady || launchReads == 1) return null;
    if (launchReads == 2) {
      return UiNode.fromJson({'packageName': 'com.lesgo.saar', 'children': []});
    }
    if (launchReads == 3 || launchReads == 4) {
      return UiNode.fromJson({
        'packageName': 'shop',
        'text': 'Loading your food',
      });
    }
    return tree;
  }
}

class Model extends LlmClient {
  Model(this.replies);
  @override
  Future<String?> connectionIssue() async => null;
  final List<String> replies;
  int calls = 0;
  @override
  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? schema,
    String schemaName = 'saar_decision',
  }) async => replies[calls++];
}

class SlowModel extends LlmClient {
  @override
  Future<String?> connectionIssue() async => null;
  final response = Completer<String?>();
  final started = Completer<void>();
  @override
  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? schema,
    String schemaName = 'saar_decision',
  }) {
    started.complete();
    return response.future;
  }
}

String action(String name, {int? target, String evidence = ''}) => jsonEncode({
  'action': name,
  'target': target,
  'text': '',
  'reason': 'Testing',
  'expectation': evidence,
});
AgentTask task() => AgentTask(id: 'test', goal: 'Find pizza', package: 'shop');
void main() {
  test('action schema only offers targets that support each action', () {
    final observation = AgentObservation(
      UiNode.fromJson({
        'children': [
          {'text': 'Label'},
          {'text': 'Row', 'isClickable': true},
          {'text': 'Input', 'isEditable': true},
          {'isScrollable': true},
          {'isClickable': true, 'isCheckable': true},
          {
            'isClickable': true,
            'children': [
              {'isCheckable': true},
            ],
          },
        ],
      }),
    );
    final branches = AdaptiveAgent.actionSchema(observation)['oneOf'] as List;
    final targets = {
      for (final branch in branches)
        branch['properties']['action']['const']:
            branch['properties']['target']['enum'],
    };
    expect(targets['tap'], [1, 2]);
    expect(targets['type'], [2]);
    expect(targets['scroll'], [3]);
    expect(targets['finish'], [null]);
    final empty = AdaptiveAgent.actionSchema(
      AgentObservation(UiNode.fromJson({})),
    );
    expect((empty['oneOf'] as List).length, 3);
  });
  test(
    'model cannot tap a checkable control even if it ignores the schema',
    () async {
      final device = Device()
        ..tree = UiNode.fromJson({
          'packageName': 'shop',
          'text': 'Switch',
          'isClickable': true,
          'isCheckable': true,
        });
      late AdaptiveAgent agent;
      agent = AdaptiveAgent(
        bridge: device,
        model: Model([action('tap', target: 0)]),
        checkpoint: (_) async {},
        onStatus: (_, waiting) {
          if (waiting) agent.stop();
        },
        settleDelay: Duration.zero,
      );
      await agent.run(task(), []);
      expect(device.taps, 0);
    },
  );
  test(
    'disabled model does not open an app and strand the user there',
    () async {
      SharedPreferences.setMockInitialValues({'enable_llm': false});
      final device = Device();
      late AdaptiveAgent agent;
      agent = AdaptiveAgent(
        bridge: device,
        model: LlmClient(),
        checkpoint: (_) async {},
        onStatus: (_, waiting) {
          if (waiting) agent.stop();
        },
        settleDelay: Duration.zero,
      );
      await agent.run(task(), []);
      expect(device.opens, 0);
      expect(device.taps, 0);
    },
  );
  test('cold launch waits through missing, previous-app and text-only loading screens before planning', () async {
    final device = LaunchingDevice();
    final waits = <String>[];
    late AdaptiveAgent agent;
    agent = AdaptiveAgent(
      bridge: device,
      model: Model([
        action('tap', target: 0),
        '{"outcome":"A","error":"None"}',
        action('finish', evidence: 'Pizza results'),
        '{"verified":true}',
      ]),
      checkpoint: (_) async {},
      onStatus: (message, waiting) {
        if (waiting) {
          waits.add(message);
          agent.stop();
        }
      },
      settleDelay: Duration.zero,
    );
    final t = task();
    await agent.run(t, []);
    expect(waits, isEmpty);
    expect(device.taps, 1);
    expect(t.status, 'completed');
  });
  test(
    'missing launch screen times out with an accessibility explanation',
    () async {
      final device = LaunchingDevice()..neverReady = true;
      final model = Model([]);
      final waits = <String>[];
      late AdaptiveAgent agent;
      agent = AdaptiveAgent(
        bridge: device,
        model: model,
        checkpoint: (_) async {},
        onStatus: (message, waiting) {
          if (waiting) {
            waits.add(message);
            agent.stop();
          }
        },
        settleDelay: Duration.zero,
      );
      await agent.run(task(), []);
      expect(waits.single, contains('screen'));
      expect(waits.single, contains('accessibility'));
      expect(waits.single, isNot(contains('sign-in')));
      expect(model.calls, 0);
      expect(device.taps, 0);
      expect(device.launchReads, lessThanOrEqualTo(12));
    },
  );
  test('rejects invented screen targets and unsupported actions', () {
    final observation = AgentObservation(screen('Search'));
    expect(
      () => AgentAction.parse(action('tap', target: 8), observation),
      throwsFormatException,
    );
    expect(
      () => AgentAction.parse(action('shell'), observation),
      throwsFormatException,
    );
    expect(
      () => AgentAction.parse(action('scroll', target: 0), observation),
      throwsFormatException,
    );
  });
  test(
    'pending checkpoint requires human review before any model action',
    () async {
      final device = Device();
      final model = Model([]);
      final restored = task()..actionPending = true;
      late AdaptiveAgent agent;
      agent = AdaptiveAgent(
        bridge: device,
        model: model,
        checkpoint: (_) async {},
        onStatus: (_, waiting) {
          if (waiting) agent.stop();
        },
        settleDelay: Duration.zero,
      );
      await agent.run(restored, []);
      expect(device.taps, 0);
      expect(model.calls, 0);
      expect(restored.status, 'cancelled');
    },
  );
  test('persisted attempted action is never automatically repeated', () async {
    final device = Device();
    final t = task();
    t.history.add({
      'screen': AgentObservation(device.tree).stateKey,
      'proposed': jsonDecode(action('tap', target: 0)),
      'outcome': 'uncertain',
    });
    late AdaptiveAgent agent;
    agent = AdaptiveAgent(
      bridge: device,
      model: Model([action('tap', target: 0)]),
      checkpoint: (_) async {},
      onStatus: (_, waiting) {
        if (waiting) agent.stop();
      },
      settleDelay: Duration.zero,
    );
    await agent.run(t, []);
    expect(device.taps, 0);
    expect(t.status, 'cancelled');
  });
  test('observes, acts, reflects and requires completion evidence', () async {
    final device = Device();
    final checkpoints = <Map<String, dynamic>>[];
    final agent = AdaptiveAgent(
      bridge: device,
      model: Model([
        action('tap', target: 0),
        '{"outcome":"A","error":"None"}',
        action('finish', evidence: 'Pizza results'),
        '{"verified":true}',
      ]),
      checkpoint: (t) async {
        checkpoints.add(Map.of(t.toJson()));
      },
      onStatus: (_, _) {},
      settleDelay: Duration.zero,
    );
    final t = task();
    await agent.run(t, []);
    expect(t.status, 'completed');
    expect(device.taps, 1);
    expect(checkpoints.any((j) => j['actionPending'] == true), isTrue);
  });
  test('stop during inference invalidates the pending action', () async {
    final device = Device();
    final model = SlowModel();
    final agent = AdaptiveAgent(
      bridge: device,
      model: model,
      checkpoint: (_) async {},
      onStatus: (_, _) {},
      settleDelay: Duration.zero,
    );
    final t = task();
    final run = agent.run(t, []);
    await model.started.future;
    agent.stop();
    model.response.complete(action('tap', target: 0));
    await run;
    expect(device.taps, 0);
    expect(t.status, 'cancelled');
  });
  test(
    'screen change during inference prevents stale-target execution',
    () async {
      final device = Device();
      final model = SlowModel();
      late AdaptiveAgent agent;
      agent = AdaptiveAgent(
        bridge: device,
        model: model,
        checkpoint: (_) async {},
        onStatus: (_, waiting) {
          if (waiting) agent.stop();
        },
        settleDelay: Duration.zero,
      );
      final run = agent.run(task(), []);
      await model.started.future;
      device.tree = screen('Different screen');
      model.response.complete(action('tap', target: 0));
      await run;
      expect(device.taps, 0);
    },
  );
  test(
    'finish without visible evidence waits rather than fabricating success',
    () async {
      final device = Device();
      late AdaptiveAgent agent;
      final t = task();
      agent = AdaptiveAgent(
        bridge: device,
        model: Model([action('finish', evidence: 'Order confirmed')]),
        checkpoint: (_) async {},
        onStatus: (_, waiting) {
          if (waiting) agent.stop();
        },
        settleDelay: Duration.zero,
      );
      await agent.run(t, []);
      expect(t.status, 'cancelled');
      expect(device.taps, 0);
    },
  );
}
