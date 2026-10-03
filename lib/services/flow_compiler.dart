import 'package:uuid/uuid.dart';

import '../models/flow.dart';
import '../models/action_trace_event.dart';
import '../models/role_ontology.dart';
import '../models/ui_node.dart';
import 'trace_normalizer.dart';

class FlowCompiler {
  final TraceNormalizer _normalizer = TraceNormalizer();

  Flow compile(String utterance, List<ActionTraceEvent> rawTrace) {
    final trace = _normalizer.normalize(rawTrace);
    if (trace.isEmpty) throw Exception('Empty trace after normalization');

    final packageCounts = <String, int>{};
    for (final event in trace) {
      final pkg = _applicationPackage(event);
      if (pkg != null) {
        packageCounts[pkg] = (packageCounts[pkg] ?? 0) + 1;
      }
    }
    final appPackage = packageCounts.isNotEmpty
        ? (packageCounts.entries.reduce((a, b) => a.value > b.value ? a : b))
              .key
        : '';

    final steps = <FlowStep>[];
    final slots = <Slot>[];
    final slotNames = <String>{};
    int stepId = 1;

    for (final event in trace) {
      final node = event.node;
      if (node == null || event.action == 'focus') continue;

      final role = _roleForAction(node, event.action, stepId);

      final roleLower = role.toLowerCase();
      final textLower = (node.text ?? '').toLowerCase();
      if (_isSensitiveRole(roleLower) || _isSensitiveRole(textLower)) {
        steps.add(
          FlowStep(id: stepId++, action: 'stop_before', targetRole: role),
        );
        continue;
      }

      String? valueSlot;
      String? valueLiteral;
      if (event.action == 'type' || event.action == 'set_quantity') {
        final typed = _typedValue(event);
        if (typed != null && typed.isNotEmpty) {
          if (_isSensitiveValue(typed)) {
            valueLiteral = '<REDACTED>';
          } else {
            final slotName = _slotNameFromRole(role);
            if (!slotNames.contains(slotName)) {
              slotNames.add(slotName);
              slots.add(Slot(name: slotName, description: 'Value for $role'));
            }
            valueSlot = slotName;
          }
        }
      }

      final precondition = role.startsWith('GENERIC_')
          ? null
          : StepPrecondition(requiredRoles: [role]);
      final recovery = ['dismiss_popup', 'scroll', 'refind_node'];

      steps.add(
        FlowStep(
          id: stepId++,
          action: event.action,
          targetRole: role,
          targetNodeText: node.text,
          targetNodeContentDescription: node.contentDescription,
          targetNodeResourceId: node.resourceId,
          scrollDeltaX: event.scrollDeltaX,
          scrollDeltaY: event.scrollDeltaY,
          valueSlot: valueSlot,
          valueLiteral: valueLiteral,
          precondition: precondition,
          recovery: recovery,
        ),
      );
    }

    return Flow(
      flowId: const Uuid().v4(),
      appPackage: appPackage,
      triggerIntent: utterance,
      exampleUtterances: [utterance],
      slots: slots,
      steps: steps,
    );
  }

  String _slotNameFromRole(String role) {
    final lower = role.toLowerCase();
    if (lower.contains('search') || lower.contains('query')) return 'query';
    if (lower.contains('quantity')) return 'quantity';
    if (lower.contains('address')) return 'address';
    return '${lower}_value';
  }

  String _roleForAction(UiNode node, String action, int stepId) {
    final inferred = RoleOntology.inferRole(node);
    if (inferred != null) return inferred;
    if (action == 'scroll') return RoleOntology.scrollView;
    return 'UI_ELEMENT_$stepId';
  }

  String? _typedValue(ActionTraceEvent event) {
    final eventValue = event.valueTyped?.trim();
    if (eventValue != null && eventValue.isNotEmpty) return eventValue;
    final nodeValue = event.node?.text?.trim();
    return nodeValue == null || nodeValue.isEmpty ? null : nodeValue;
  }

  String? _applicationPackage(ActionTraceEvent event) {
    final eventPackage = event.packageName?.trim();
    final nodePackage = event.node?.packageName?.trim();
    final packageName = eventPackage?.isNotEmpty == true
        ? eventPackage
        : nodePackage;
    if (packageName == null || packageName.isEmpty) return null;
    if (packageName == 'com.lesgo.saar' ||
        packageName == 'android' ||
        packageName.startsWith('com.android.') ||
        packageName == 'com.miui.home' ||
        packageName == 'com.google.android.apps.nexuslauncher') {
      return null;
    }
    return packageName;
  }

  /// Whole-word matching only: a plain `contains` would treat "Shopping Bag"
  /// as sensitive because it contains "pin", turning ordinary taps into
  /// `stop_before` steps that never replay.
  static final RegExp _sensitiveWord = RegExp(
    r'(^|[^a-z0-9])('
    r'password|otp|pin|cvv|cvc|mpin|payment|pay|place[ _-]?order|login|biometric'
    r')($|[^a-z0-9])',
    caseSensitive: false,
  );

  bool _isSensitiveRole(String s) => _sensitiveWord.hasMatch(s);

  /// Only redacts values that look like a card number. Short numeric values
  /// are ordinary input (quantities, sizes, house numbers) and redacting them
  /// would strip the slot the flow needs.
  bool _isSensitiveValue(String s) =>
      RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b').hasMatch(s);
}
