import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/services/flow_matcher.dart';
import 'package:saar/services/flow_store.dart';
import 'package:saar/services/intent_model.dart';

import 'app_controller_test.dart' show MemoryStore;

Flow skill(String id, {String trigger = 'Order food from swiggy'}) => Flow(
  flowId: id,
  appPackage: 'in.swiggy.android',
  triggerIntent: trigger,
  exampleUtterances: ['My usual meal'],
  slots: [Slot(name: 'query', defaultValue: 'pizza')],
  steps: [],
);

void main() {
  test(
    'exact and saved example commands use demonstrated values without an index',
    () async {
      final matcher = FlowMatcher(MemoryStore(saved: [skill('one')]));
      for (final text in ['Order  food from SWIGGY!', 'My usual meal.']) {
        final result = await matcher.match(text);
        expect(result.flow?.flowId, 'one');
        expect(result.resolvedSlots['query'], 'pizza');
        expect(result.isUnknown, isFalse);
      }
    },
  );
  test(
    'polite requests still identify the exact demonstrated command',
    () async {
      final matcher = FlowMatcher(MemoryStore(saved: [skill('one')]));
      for (final text in [
        'Please order food from Swiggy',
        'Can you order food from Swiggy?',
        'Could you please order food from swiggy?',
      ]) {
        final result = await matcher.matchExact(text);
        expect(result?.flow?.flowId, 'one', reason: text);
        expect(result?.resolvedSlots['query'], 'pizza');
      }
      for (final text in [
        "Don't order food from swiggy",
        'Why order food from swiggy?',
        'Order food from zomato',
      ]) {
        expect(await matcher.matchExact(text), isNull, reason: text);
      }
    },
  );
  test('duplicate exact commands require choosing a workflow', () async {
    final result = await FlowMatcher(
      MemoryStore(saved: [skill('one'), skill('two')]),
    ).match('Order food from swiggy');
    expect(result.flow, isNull);
    expect(result.candidates, hasLength(2));
    expect(result.needsClarification, isTrue);
  });
  test(
    'lexical similarity cannot cross operations or explicitly requested apps',
    () async {
      final model = LocalIntentModel();
      final saved = skill('one', trigger: 'Search food from swiggy');
      final store = MemoryStore(saved: [saved]);
      // Use a real hash vector: only app/operation compatibility can reject it.
      final indexed = MemoryStore(
        saved: store.saved,
        embeddings: [
          FlowEmbedding(
            flowId: saved.flowId,
            vector: await model.embed(saved.triggerIntent),
          ),
        ],
      );
      final matcher = FlowMatcher(indexed, localModel: model)
        ..appNames = {saved.appPackage: 'Swiggy', 'com.amazon.shop': 'Amazon'};
      expect((await matcher.match('Order food from swiggy')).isUnknown, isTrue);
      expect(
        (await matcher.match('Search food from amazon')).isUnknown,
        isTrue,
      );
      expect(
        (await matcher.match('Why search food from swiggy')).isUnknown,
        isTrue,
      );
    },
  );
}
