import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_controller.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF007BFF),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
