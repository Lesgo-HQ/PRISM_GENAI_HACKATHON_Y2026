import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/execution_report.dart';
import 'package:saar/models/parsed_intent.dart';
import 'package:saar/models/replay_session.dart';
import 'package:saar/models/screen_snapshot.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/credential_guard.dart';
import 'package:saar/services/slot_extractor.dart';
import 'package:saar/services/intent_model.dart';

UiNode _node({
  String? text,
  String? resourceId,
  String? contentDescription,
  String? hintText,
  String? className,
  bool clickable = false,
  bool editable = false,
  int inputType = 0,
  int left = 0,
}) => UiNode(
  text: text,
  resourceId: resourceId,
  contentDescription: contentDescription,
  hintText: hintText,
  className: className,
  packageName: 'com.example.shop',
  bounds: {'left': left, 'top': 0, 'right': left + 10, 'bottom': 10},
  isClickable: clickable,
  isEditable: editable,
  isScrollable: false,
  isCheckable: false,
  isChecked: false,
  isFocusable: false,
  isFocused: false,
  inputType: inputType,
  children: const [],
);

void main() {
  test('ParsedIntent creation and serialization', () {
    final intent = ParsedIntent(
      intent: 'ORDER_ITEM',
      slots: {'item': 'rice'},
      confidence: 0.9,
    );
    final json = intent.toJson();
    final restored = ParsedIntent.fromJson(json);
    expect(restored.intent, 'ORDER_ITEM');
    expect(restored.slots['item'], 'rice');
  });

  test('ParsedIntent unknown factory', () {
    final intent = ParsedIntent.unknown();
    expect(intent.isUnknown, isTrue);
  });

  test('Flow serialization roundtrip', () {
    final flow = Flow(
      flowId: 'f1',
      appPackage: 'com.example.shop',
      triggerIntent: 'order rice',
      exampleUtterances: const ['order rice'],
      slots: const [],
      steps: [FlowStep(id: 1, action: 'tap', targetRole: 'ADD_TO_CART')],
    );
    final json = flow.toJson();
    final restored = Flow.fromJson(json);
    expect(restored.flowId, 'f1');
    expect(restored.steps.length, 1);
    expect(restored.steps.first.targetRole, 'ADD_TO_CART');
  });

  test('FlowStep precondition validation', () {
    final step = FlowStep(
      id: 1,
      action: 'tap',
      targetRole: 'ADD_TO_CART',
      precondition: StepPrecondition(
        requiredRoles: ['PRODUCT_DETAIL'],
        forbiddenRoles: ['PASSWORD', 'OTP', 'PAYMENT'],
      ),
    );
    expect(
      step.validatePrecondition({'PRODUCT_DETAIL', 'ADD_TO_CART'}),
      isTrue,
    );
    expect(step.validatePrecondition({'PRODUCT_DETAIL', 'PASSWORD'}), isFalse);
    expect(step.validatePrecondition({'SEARCH_FIELD'}), isFalse);
  });

  test('ScreenSnapshot hash ignores coordinates', () {
    final first = ScreenSnapshot.fromTree(
      _node(text: 'Cart', left: 0),
      rolesForNode: (_) => ['CART'],
    );
    final second = ScreenSnapshot.fromTree(
      _node(text: 'Cart', left: 500),
      rolesForNode: (_) => ['CART'],
    );
    expect(first.stateHash, second.stateHash);
  });

  test('ReplaySession pause/resume preserves step', () {
    final flow = Flow(
      flowId: 'f1',
      appPackage: 'com.example.shop',
      triggerIntent: 'order rice',
      exampleUtterances: const ['order rice'],
      slots: const [],
      steps: [FlowStep(id: 1, action: 'tap', targetRole: 'ADD_TO_CART')],
    );
    final session = ReplaySession(
      runId: 'run',
      flow: flow,
      slots: const {},
      currentStep: 3,
    )..start();
    session.pause();
    expect(session.status, ReplayStatus.waitingForUser);
    session.resume();
    expect(session.currentStep, 3);
    expect(session.status, ReplayStatus.executing);
  });

  test('CredentialGuard blocks password fields', () {
    expect(
      CredentialGuard.isSensitiveScreen(
        _node(text: 'Enter password', editable: true),
      ),
      isTrue,
    );
    expect(
      CredentialGuard.isSensitiveScreen(
        _node(resourceId: 'com.app:id/otp_field'),
      ),
      isTrue,
    );
    expect(
      CredentialGuard.isSensitiveScreen(_node(inputType: 0x80, editable: true)),
      isTrue,
    );
  });

  test('CredentialGuard fails closed on null', () {
    expect(CredentialGuard.isSensitiveScreen(null), isTrue);
  });

  test('CredentialGuard allows normal fields', () {
    expect(
      CredentialGuard.isSensitiveScreen(_node(text: 'Rice', clickable: true)),
      isFalse,
    );
  });

  test('SlotExtractor extracts items and quantities', () {
    final extractor = SlotExtractor();
    final slots = extractor.extract('order 2 packets of rice from zepto');
    expect(slots['quantity'], isNotNull);
    expect(slots['app'], 'zepto');
  });

  test('LocalIntentModel classifies known intents', () async {
    final model = LocalIntentModel();
    final result = await model.parse('search for rice');
    expect(result.intent, 'search');
    expect(result.isUnknown, isFalse);
  });

  test('LocalIntentModel detects unknown intents', () async {
    final model = LocalIntentModel();
    final result = await model.parse('play some music');
    expect(result.isUnknown, isTrue);
  });

  test('ExecutionReport summary', () {
    final report = ExecutionReport(
      runId: 'abcd1234',
      flowId: 'f1',
      flowName: 'Order rice',
      status: ReportStatus.halted,
      stepsCompleted: 5,
      totalSteps: 8,
      reason: 'Payment screen detected',
      startTime: DateTime(2024, 1, 1),
      endTime: DateTime(2024, 1, 1, 0, 0, 30),
    );
    expect(report.summary, contains('HALTED'));
    expect(report.summary, contains('Payment screen detected'));
  });
}
