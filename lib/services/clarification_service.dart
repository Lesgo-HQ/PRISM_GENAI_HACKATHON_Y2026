import 'dart:async';

import '../models/flow.dart';

class ClarificationService {
  Completer<String>? _pendingResponse;

  /// Build a clarification question for ambiguous match
  String buildMatchClarification(List<Flow> candidates) {
    if (candidates.isEmpty) return "I couldn't find a matching flow.";
    final options = candidates.map((c) => "'${c.triggerIntent}'").join(' or ');
    return "I found multiple matching flows: $options. Which one did you mean?";
  }

  /// Build a clarification question for missing slot
  String buildSlotClarification(
    String slotName,
    String slotType,
    List<String>? enumValues,
  ) {
    if (enumValues != null && enumValues.isNotEmpty) {
      return "What value should I use for $slotName? Options are: ${enumValues.join(', ')}.";
    }
    return "What value should I use for $slotName?";
  }

  /// Build a clarification question for replay failure
  String buildReplayClarification(
    String stepDescription,
    String currentScreenDesc,
  ) {
    return "I'm stuck at step: $stepDescription. The screen shows: $currentScreenDesc. What should I do?";
  }

  /// Ask user a question and wait for response
  Future<String> askUser(String question) async {
    _pendingResponse = Completer<String>();
    return _pendingResponse!.future;
  }

  /// Provide user's response to pending question
  void provideResponse(String response) {
    _pendingResponse?.complete(response);
    _pendingResponse = null;
  }

  bool get hasPendingQuestion =>
      _pendingResponse != null && !_pendingResponse!.isCompleted;
}
