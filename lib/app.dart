import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';

class BillSplitApp extends StatelessWidget {
  const BillSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Divide la Cuenta',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
