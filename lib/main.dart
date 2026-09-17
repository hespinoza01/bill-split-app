import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterGemma.initialize();

  final db = AppDatabase();
  runApp(
    Provider<AppDatabase>.value(
      value: db,
      child: const BillSplitApp(),
    ),
  );
}
