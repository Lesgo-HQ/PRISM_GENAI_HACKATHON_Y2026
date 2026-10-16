import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_controller.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final entry in {
      'Roubao': ['roubao-LICENSE.txt'],
      'ClosePaw': ['closepaw-LICENSE.txt', 'closepaw-NOTICE.txt'],
    }.entries) {
      for (final file in entry.value) {
        yield LicenseEntryWithLineBreaks([
          entry.key,
        ], await rootBundle.loadString('assets/licenses/$file'));
      }
    }
  });
  runApp(const SaarApp());
}

class SaarApp extends StatelessWidget {
  const SaarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController()..initialize(),
      child: MaterialApp(
        title: 'SAAR',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
