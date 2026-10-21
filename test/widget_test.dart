import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saar/app_controller.dart';
import 'package:saar/main.dart';
import 'package:saar/screens/home_screen.dart';
import 'package:saar/screens/replay_screen.dart';

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
