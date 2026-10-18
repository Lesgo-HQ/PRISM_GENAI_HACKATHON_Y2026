import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/action_trace_event.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/flow_compiler.dart';
import 'package:saar/services/node_ranker.dart';

void main() {
  test('unlabelled clickable rows preserve their child label for replay', () {
    UiNode row(String label) => UiNode.fromJson({
      'packageName': 'com.android.settings',
      'isClickable': true,
      'children': [
        {'text': label, 'children': []},
      ],
    });
    final target = row('Display');
    final flow = FlowCompiler().compile('Open display settings', [
      ActionTraceEvent(
        timestampMs: 1,
        action: 'tap',
        packageName: 'com.android.settings',
        node: target,
      ),
    ]);
    expect(flow.steps.single.targetNodeText, 'Display');
    final match = NodeRanker().best(
      [row('Notifications'), target, ...target.children],
      flow.steps.single.targetRole,
      'tap',
      targetNodeText: flow.steps.single.targetNodeText,
    );
    expect(match?.node, same(target));
    expect(match?.isAmbiguous, isFalse);
  });
  ActionTraceEvent event(
    String package, {
    String text = 'Search',
    String action = 'tap',
    bool scrollable = false,
  }) => ActionTraceEvent(
    timestampMs: 1,
    action: action,
    packageName: package,
    node: UiNode.fromJson({
      'packageName': package,
      'text': text,
      'isClickable': !scrollable,
      'isScrollable': scrollable,
      'children': [],
    }),
  );
  test(
    'recording only SAAR or launcher interactions cannot become a learned flow',
    () {
      expect(
        () => FlowCompiler().compile('test', [event('com.lesgo.saar')]),
        throwsFormatException,
      );
      expect(
        () => FlowCompiler().compile('test', [event('com.android.launcher3')]),
        throwsException,
      );
    },
  );
  test('real system apps such as Settings are valid teaching targets', () {
    final flow = FlowCompiler().compile('Open display settings', [
      event('com.android.settings', text: 'Display'),
    ]);
    expect(flow.appPackage, 'com.android.settings');
    expect(flow.steps.single.action, 'tap');
  });
  test('payment trace becomes a manual boundary without storing its text', () {
    final flow = FlowCompiler().compile('Order food', [
      event('in.swiggy.android', text: 'Pay now'),
    ]);
    expect(flow.steps.single.action, 'stop_before');
    expect(flow.steps.single.targetNodeText, isNull);
  });
  test(
    'recorded scroll container is grounded even when it is not clickable',
    () {
      final trace = event(
        'test.app',
        text: '',
        action: 'scroll',
        scrollable: true,
      );
      final flow = FlowCompiler().compile('Browse catalog', [trace]);
      final match = NodeRanker().best(
        [trace.node!],
        flow.steps.single.targetRole,
        'scroll',
      );
      expect(match, isNotNull);
      expect(match!.isAmbiguous, isFalse);
    },
  );
}
