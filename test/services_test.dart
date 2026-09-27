import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/action_trace_event.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/trace_normalizer.dart';
import 'package:saar/services/slot_extractor.dart';
import 'package:saar/services/saar_nlu.dart';

UiNode _node({
  String? text,
  String? resourceId,
  String? packageName,
  String? nodeId,
}) => UiNode(
  nodeId: nodeId,
  text: text,
  resourceId: resourceId,
  packageName: packageName ?? 'com.example.app',
  bounds: {'left': 0, 'top': 0, 'right': 100, 'bottom': 50},
  isClickable: true,
  isEditable: false,
  isScrollable: false,
  isCheckable: false,
  isChecked: false,
  isFocusable: false,
  isFocused: false,
  inputType: 0,
  children: const [],
);

void main() {
  group('TraceNormalizer', () {
    test('filters system packages', () {
      final normalizer = TraceNormalizer();
      final trace = [
        ActionTraceEvent(
          timestampMs: 100,
          action: 'tap',
          node: _node(text: 'ok'),
          packageName: 'com.android.systemui',
        ),
        ActionTraceEvent(
          timestampMs: 200,
          action: 'tap',
          node: _node(text: 'Buy'),
          packageName: 'com.example.shop',
        ),
      ];
      final result = normalizer.normalize(trace);
      expect(result.length, 1);
      expect(result.first.packageName, 'com.example.shop');
    });

    test('merges consecutive type events on same node', () {
      final normalizer = TraceNormalizer();
      final trace = [
        ActionTraceEvent(
          timestampMs: 100,
          action: 'type',
          node: _node(nodeId: 'search'),
          valueTyped: 'ri',
        ),
        ActionTraceEvent(
          timestampMs: 200,
          action: 'type',
          node: _node(nodeId: 'search'),
          valueTyped: 'rice',
        ),
      ];
      final result = normalizer.normalize(trace);
      expect(result.length, 1);
      expect(result.first.valueTyped, 'rice');
    });
  });

  group('SlotExtractor', () {
    test('redactSensitive removes card numbers', () {
      final ext = SlotExtractor();
      expect(ext.redactSensitive('card 1234-5678-9012-3456'), contains('****'));
    });
  });

  group('SaarNlu', () {
    test('understand returns parsed intent with slots', () async {
      final nlu = SaarNlu();
      final result = await nlu.understand('search for rice on zepto');
      expect(result.intent, isNotEmpty);
      expect(result.isUnknown, isFalse);
    });
  });
}
