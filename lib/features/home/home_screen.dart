import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../capture/capture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final currency = NumberFormat.simpleCurrency();

    return Scaffold(
      appBar: AppBar(title: const Text('Facturas')),
      body: StreamBuilder<List<Bill>>(
        stream: db.billsDao.watchAllBills(),
        builder: (context, snapshot) {
          final bills = snapshot.data ?? const <Bill>[];
          if (snapshot.connectionState == ConnectionState.waiting && bills.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (bills.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin facturas todavía.\nToca + para escanear tu primera factura.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return ListTile(
                title: Text(bill.restaurantName ?? 'Factura sin nombre'),
                subtitle: Text(DateFormat.yMMMd().format(bill.date)),
                trailing: Text(currency.format(bill.total)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CaptureScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
