import 'package:uuid/uuid.dart';

import '../models/flow.dart';
import '../models/action_trace_event.dart';
import '../models/role_ontology.dart';
import 'trace_normalizer.dart';

class FlowCompiler {
  final TraceNormalizer _normalizer = TraceNormalizer();

  Flow compile(String utterance, List<ActionTraceEvent> rawTrace) {
    final trace = _normalizer.normalize(rawTrace);
    if (trace.isEmpty) throw Exception('Empty trace after normalization');

    final packageCounts = <String, int>{};
    for (final event in trace) {
      final pkg = event.packageName ?? event.node?.packageName;
      if (pkg != null && pkg.isNotEmpty) {
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

      final role = RoleOntology.inferRole(node) ?? 'GENERIC_$stepId';

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
        final typed = event.valueTyped;
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

  bool _isSensitiveRole(String s) => RegExp(
    r'password|otp|pin|cvv|cvc|payment|pay\b|place_order|login|biometric',
    caseSensitive: false,
  ).hasMatch(s);

  bool _isSensitiveValue(String s) =>
      RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b|\b\d{3}\b')
          .hasMatch(s) ||
      s.length <= 2;
}
