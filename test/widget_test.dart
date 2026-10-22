import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:provider/provider.dart';
import 'package:saar/app_controller.dart';
import 'package:saar/main.dart';
import 'package:saar/screens/home_screen.dart';
import 'package:saar/screens/replay_screen.dart';
import 'package:saar/models/flow.dart';

class SkillLibraryController extends AppController {
  String? submitted;
  @override
  List<Flow> get flows => [
    Flow(
      flowId: 'demo',
      appPackage: 'example.app',
      triggerIntent: 'Find coffee',
      exampleUtterances: [],
      slots: [],
      steps: [],
    ),
  ];
  @override
  Future<void> submitTypedCommand(String utterance) async {
    submitted = utterance;
  }
}

class AppChoiceController extends AppController {
  @override
  AppState get state => AppState.waitingForClarification;
  @override
  String get statusMessage => clarificationQuestion;
  @override
  String get clarificationQuestion =>
      List.generate(100, (i) => '${i + 1}. Installed app $i').join('\n');
}

class LongStatusController extends AppController {
  @override
  AppState get state => AppState.matching;
  @override
  String get statusMessage =>
      'Understanding a long command to open display settings on this phone';
}

void main() {
  testWidgets('visible skill library runs the selected learned command', (
    tester,
  ) async {
    final controller = SkillLibraryController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.tap(find.text('Learned skills (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Find coffee').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Run skill'));
    await tester.pump();
    expect(controller.submitted, 'Find coffee');
    expect(tester.takeException(), isNull);
  });
  testWidgets('long app choice remains scrollable with keyboard space', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppChoiceController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: ReplayScreen()),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('STOP EXECUTION'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('STOP EXECUTION').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SaarApp());
    expect(find.text('SAAR'), findsOneWidget);
  });
  testWidgets('long status fits a phone-width header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 873));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = LongStatusController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
