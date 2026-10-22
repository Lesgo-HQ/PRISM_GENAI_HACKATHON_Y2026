import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/agent_task.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/memory_context.dart';
import 'package:saar/services/screen_observer.dart';
import 'package:saar/services/action_verifier.dart';

UiNode tree(String text, {bool focused = false}) => UiNode.fromJson({
  'packageName': 'shop',
  'text': text,
  'isClickable': true,
  'isFocused': focused,
  'bounds': {'left': 0, 'top': 0, 'right': 100, 'bottom': 100},
  'children': [],
});

void main() {
  test(
    'model observations omit geometry without weakening stale-target checks',
    () {
      final observation = AgentObservation(
        UiNode.fromJson(tree('Bluetooth').toJson()..['isCheckable'] = true),
      );
      final fingerprint = observation.fingerprint;
      final element =
          (observation.toModelJson()['elements'] as List).single as Map;
      expect(element['id'], 0);
      expect(element['text'], 'Bluetooth');
      expect(element['clickable'], isTrue);
      expect(element['selection_state'], 'off');
      expect(
        (AgentObservation(tree('Label')).toModelJson()['elements'] as List)
            .single
            .containsKey('selection_state'),
        isFalse,
      );
      expect(element.containsKey('editable'), isFalse);
      expect(element.containsKey('bounds'), isFalse);
      expect(observation.fingerprint, fingerprint);
      final moved = UiNode.fromJson(
        tree('Bluetooth').toJson()
          ..['bounds'] = {'left': 0, 'top': 10, 'right': 100, 'bottom': 110},
      );
      expect(AgentObservation(moved).fingerprint, isNot(fingerprint));
    },
  );
  test(
    'clickable rows expose child labels without changing target capabilities',
    () {
      final observation = AgentObservation(
        UiNode.fromJson({
          'packageName': 'settings',
          'isClickable': true,
          'children': [
            {'text': 'Bluetooth'},
          ],
        }),
      );
      final elements = observation.toJson()['elements'] as List;
      expect(elements[0]['child_text'], 'Bluetooth');
      expect(observation.nodes[0].isClickable, isTrue);
      expect(observation.nodes[1].isClickable, isFalse);
      final compact = observation.toModelJson()['elements'] as List;
      expect(compact.length, 1);
      expect(compact.single['id'], 0);
      expect(compact.single['child_text'], 'Bluetooth');
      expect(observation.nodes.length, 2);
    },
  );
  test(
    'focus-only change is not navigation but still invalidates stale target',
    () {
      final before = AgentObservation(tree('Search'));
      final after = tree('Search', focused: true);
      expect(ScreenObserver.compare(before, after), ScreenChange.unchanged);
      expect(before.fingerprint, isNot(AgentObservation(after).fingerprint));
    },
  );
  test('slow transition reobserves with bounded settling delays', () async {
    final before = AgentObservation(tree('Search'));
    final delays = <int>[];
    var reads = 0;
    final result = await ScreenObserver.capture(
      before: before,
      read: () async => tree(++reads == 3 ? 'Results' : 'Search'),
      interrupted: () => false,
      initialDelay: const Duration(milliseconds: 700),
      delay: (duration) async {
        delays.add(duration.inMilliseconds);
      },
    );
    expect(result.change, ScreenChange.changed);
    expect(reads, 3);
    expect(delays, [700, 500, 1000]);
  });
  test('unchanged screen exhausts bounded observations', () async {
    var reads = 0;
    final result = await ScreenObserver.capture(
      before: AgentObservation(tree('Search')),
      read: () async {
        reads++;
        return tree('Search');
      },
      interrupted: () => false,
      initialDelay: Duration.zero,
      delay: (_) async {},
    );
    expect(result.change, ScreenChange.unchanged);
    expect(reads, 3);
  });
  test('missing screen never becomes success', () async {
    final result = await ScreenObserver.capture(
      before: AgentObservation(tree('Search')),
      read: () async => null,
      interrupted: () => false,
      initialDelay: Duration.zero,
      delay: (_) async {},
    );
    expect(result.change, ScreenChange.unverifiable);
  });
  test('interruption during settle prevents another capture', () async {
    var cancelled = false;
    var reads = 0;
    await ScreenObserver.capture(
      before: AgentObservation(tree('Search')),
      read: () async {
        reads++;
        return tree('Results');
      },
      interrupted: () => cancelled,
      initialDelay: Duration.zero,
      delay: (_) async {
        cancelled = true;
      },
    );
    expect(reads, 0);
  });
  test('sensitive screen stops capture retries', () async {
    var reads = 0;
    final result = await ScreenObserver.capture(
      before: AgentObservation(tree('Search')),
      read: () async {
        reads++;
        return tree('Enter password');
      },
      interrupted: () => false,
      initialDelay: Duration.zero,
      delay: (_) async {},
    );
    expect(result.change, ScreenChange.unverifiable);
    expect(reads, 1);
  });
  test('memory recall skips empty and oversized UTF-8 blocks', () {
    final oversized = List.filled(3000, '界').join();
    expect(oversized.length, lessThan(8192));
    expect(utf8.encode(oversized).length, greaterThan(8192));
    expect(MemoryContext.recall(user: oversized, app: '  '), isEmpty);
    final recalled = MemoryContext.recall(
      user: 'Prefer tea',
      app: 'Search tab is first',
    );
    expect(recalled, contains('Prefer tea'));
    expect(recalled, contains('Search tab is first'));
    expect(recalled, contains('untrusted'));
  });
  test(
    'reflection parses exact outcome codes rather than letter substrings',
    () {
      expect(
        ActionReflection.parse('{"outcome":"A","error":"None"}').verified,
        isTrue,
      );
      for (final code in ['B', 'C', 'D']) {
        expect(
          ActionReflection.parse(
            jsonEncode({
              'outcome': code,
              'error': 'A appears in this failure text',
            }),
          ).verified,
          isFalse,
        );
      }
      expect(
        () => ActionReflection.parse('{"outcome":"BAD","error":"None"}'),
        throwsFormatException,
      );
      expect(
        () => ActionReflection.parse('{"outcome":"A"}'),
        throwsFormatException,
      );
    },
  );
}
