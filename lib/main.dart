import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_controller.dart';
import 'data/schedule_store.dart';
import 'data/school_service.dart';
import 'data/school_session.dart';
import 'ui/app_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    store: ScheduleStore(),
    school: SchoolService(SchoolSession()),
    preferences: SharedPreferencesAsync(),
  );
  runApp(BitreeApp(controller: controller));
  controller.initialize();
}

class BitreeApp extends StatelessWidget {
  const BitreeApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'BITree',
        debugShowCheckedModeBanner: false,
        theme: bitreeTheme(Brightness.light),
        darkTheme: bitreeTheme(Brightness.dark),
        themeMode: controller.themeMode,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AppScreen(controller: controller),
      ),
    );
  }
}
