import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'services/theme_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterGemma.initialize();

  final db = AppDatabase();
  final themeModeNotifier = ThemeModeNotifier();
  try {
    await themeModeNotifier.load();
  } catch (_) {
    // Si falla la lectura de preferencias (raro, ej. plugin no listo en
    // algún embedder), sigue con el default (system) en vez de crashear
    // antes de poder mostrar cualquier pantalla.
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<ThemeModeNotifier>.value(value: themeModeNotifier),
      ],
      child: const BillSplitApp(),
    ),
  );
}
