import '../models/parsed_intent.dart';
import 'intent_model.dart';
import 'slot_extractor.dart';

class SaarNlu {
  final LocalIntentModel _model = LocalIntentModel();
  final SlotExtractor _extractor = SlotExtractor();

  Future<ParsedIntent> understand(String utterance) async {
    final parsed = await _model.parse(utterance);
    // Merge/validate slots
    final extractedSlots = _extractor.extract(utterance);
    final mergedSlots = <String, dynamic>{...extractedSlots, ...parsed.slots};
    return ParsedIntent(
      intent: parsed.intent,
      app: parsed.app ?? _extractor.extractApp(utterance),
      slots: mergedSlots,
      confidence: parsed.confidence,
      isAmbiguous: parsed.isAmbiguous,
      embedding: await _model.embed(utterance),
    );
  }

  Future<List<double>> embed(String text) => _model.embed(text);
}
