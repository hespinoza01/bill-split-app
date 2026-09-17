import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/db/app_database.dart';

void main() {
  final db = AppDatabase();
  runApp(
    Provider<AppDatabase>.value(
      value: db,
      child: const BillSplitApp(),
    ),
  );
}
