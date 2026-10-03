import 'dart:math';

import '../models/flow.dart';
import '../models/parsed_intent.dart';
import 'flow_store.dart';
import 'intent_model.dart';
import 'slot_extractor.dart';

class MatchResult {
  final Flow? flow;
  final double confidence;
  final double margin;
  final Map<String, dynamic> resolvedSlots;
  final bool needsClarification;
  final String? clarificationQuestion;
  final bool isUnknown;
  final ParsedIntent? parsedIntent;
  MatchResult({
    this.flow,
    this.confidence = 0,
    this.margin = 0,
    this.resolvedSlots = const {},
    this.needsClarification = false,
    this.clarificationQuestion,
    this.isUnknown = false,
    this.parsedIntent,
  });
}

class FlowMatcher {
  final FlowStore _store;
  final LocalIntentModel? _local;
  final SlotExtractor _extractor = SlotExtractor();
  static const double _threshold = 0.65;
  static const double _unknownThreshold = 0.45;
  static const double _marginThreshold = 0.07;
  static const int _topK = 3;

  FlowMatcher(this._store, {LocalIntentModel? localModel})
    : _local = localModel;

  Future<MatchResult> match(
    String utterance, {
    Map<String, dynamic> extractedSlots = const {},
  }) async {
    final slots = extractedSlots.isEmpty
        ? _extractor.extract(utterance)
        : extractedSlots;

    final normalizedUtterance = _normalize(utterance);
    final savedFlows = await _store.getAllFlows();
    for (final flow in savedFlows) {
      if (_normalize(flow.triggerIntent) == normalizedUtterance) {
        final resolved = _resolveSlots(flow, slots);
        final hasUnresolved = resolved.values.any((v) => v == null);
        return MatchResult(
          flow: flow,
          confidence: 1.0,
          resolvedSlots: resolved,
          needsClarification: hasUnresolved,
          clarificationQuestion: hasUnresolved
              ? _slotQuestion(flow, resolved)
              : null,
        );
      }
    }

    ParsedIntent? parsed;
    final local = _local;
    if (local != null) {
      try {
        parsed = await local.parse(utterance);
      } catch (_) {}
    }
    if (_store.embeddings.isEmpty || local == null) {
      return MatchResult(
        isUnknown: true,
        needsClarification: true,
        clarificationQuestion: "I don't have a learned workflow for that task. Would you like to teach me?",
        parsedIntent: parsed,
      );
    }
    final emb = await local.embed(utterance);
    final sims =
        _store.embeddings.map((e) => MapEntry(e, _cos(emb, e.vector))).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final top = sims.take(_topK).toList();
    if (top.isEmpty) {
      return MatchResult(
        isUnknown: true,
        needsClarification: true,
        clarificationQuestion: "I don't have a learned workflow for that task. Would you like to teach me?",
        parsedIntent: parsed,
      );
    }
    final best = top.first;
    final second = top.length > 1 ? top[1].value : 0.0;
    final margin = best.value - second;
    if (best.value < _unknownThreshold) {
      return MatchResult(
        isUnknown: true,
        confidence: best.value,
        margin: margin,
        needsClarification: true,
        clarificationQuestion: "I don't have a learned workflow for that task. Would you like to teach me?",
        parsedIntent: parsed,
      );
    }
    final candidates = [] as List<Flow>;
    for (final e in top) {
      final f = await _store.getFlow(e.key.flowId);
      if (f != null) candidates.add(f);
    }
    if (candidates.isEmpty) {
      return MatchResult(
        isUnknown: true,
        needsClarification: true,
        clarificationQuestion: "I don't have a learned workflow for that task. Would you like to teach me?",
      );
    }
    final isAmbiguous = margin < _marginThreshold && candidates.length > 1;
    if (isAmbiguous) {
      final q = _ambiguityQuestion(candidates.take(2).toList());
      return MatchResult(
        confidence: best.value,
        margin: margin,
        needsClarification: true,
        clarificationQuestion: q,
        parsedIntent: parsed,
      );
    }
    if (best.value < _threshold) {
      return MatchResult(
        confidence: best.value,
        margin: margin,
        needsClarification: true,
        clarificationQuestion:
            'I found "${candidates.first.triggerIntent}" but I\'m not fully confident. Should I proceed?',
        parsedIntent: parsed,
      );
    }
    final flow = candidates.first;
    final resolved = _resolveSlots(flow, slots);
    final hasUnresolved = resolved.values.any((v) => v == null);
    return MatchResult(
      flow: flow,
      confidence: best.value,
      margin: margin,
      resolvedSlots: resolved,
      needsClarification: hasUnresolved,
      clarificationQuestion: hasUnresolved
          ? _slotQuestion(flow, resolved)
          : null,
      parsedIntent: parsed,
    );
  }

  String _ambiguityQuestion(List<Flow> c) {
    final opts = c
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.triggerIntent}')
        .join('\n');
    return 'I found two possible workflows:\n$opts\nWhich one do you want?';
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  double _cos(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      return 0;
    }
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) {
      return 0;
    }
    return dot / (sqrt(na) * sqrt(nb));
  }

  Map<String, dynamic> _resolveSlots(Flow flow, Map<String, dynamic> ex) {
    final m = <String, dynamic>{};
    for (final s in flow.slots) {
      if (ex.containsKey(s.name)) {
        m[s.name] = ex[s.name];
      } else if (s.defaultValue != null) {
        m[s.name] = s.defaultValue;
      } else {
        m[s.name] = null;
      }
    }
    return Map<String, dynamic>.from(m);
  }

  String _slotQuestion(Flow f, Map<String, dynamic> r) {
    final u = r.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();
    if (u.length == 1) {
      final d = f.slots.firstWhere(
        (s) => s.name == u.first,
        orElse: () => f.slots.first,
      );
      if (d.values != null && d.values!.isNotEmpty) {
        return 'What ${u.first}? Options: ${d.values!.join(', ')}';
      }
      return 'What ${u.first} should I use?';
    }
    return 'I need values for: ${u.join(', ')}. Please specify.';
  }
}
