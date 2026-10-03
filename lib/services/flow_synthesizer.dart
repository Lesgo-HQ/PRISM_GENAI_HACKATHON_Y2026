import '../models/flow.dart';
import '../models/action_trace_event.dart';
import 'flow_compiler.dart';

class FlowSynthesizer {
  final FlowCompiler _compiler = FlowCompiler();

  static final RegExp _sensitiveRole = RegExp(
    r'(^|[^a-z0-9])('
    r'password|otp|pin|cvv|cvc|payment|pay|place[ _-]?order'
    r')($|[^a-z0-9])',
    caseSensitive: false,
  );

  FlowSynthesizer();

  Future<Flow> synthesize(
    String utterance,
    List<ActionTraceEvent> trace,
  ) async {
    final flow = _compiler.compile(utterance, trace);
    _validate(flow);
    return flow;
  }

  void _validate(Flow f) {
    const allowed = {
      'tap',
      'type',
      'select',
      'swipe',
      'set_quantity',
      'scroll',
      'stop_before',
    };
    for (final s in f.steps) {
      if (!allowed.contains(s.action)) {
        throw Exception('Invalid action ${s.action}');
      }
      if (s.targetRole.isEmpty) throw Exception('Missing target_role');
      if (_sensitiveRole.hasMatch(s.targetRole) && s.action != 'stop_before') {
        throw Exception('Credential/payment role not allowed');
      }
    }
    if (f.flowId.isEmpty || f.triggerIntent.isEmpty) {
      throw Exception('Invalid flow metadata');
    }
  }
}
