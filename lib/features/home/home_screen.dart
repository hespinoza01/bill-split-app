import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../capture/capture_screen.dart';
import '../people_groups/people_groups_screen.dart';
import '../settings/settings_screen.dart';
import '../summary/bill_detail_screen.dart';
import '../summary/payment_status.dart';
import '../summary/payment_status_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final currency = NumberFormat.simpleCurrency();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Personas y grupos',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PeopleGroupsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat.yMMMd().format(bill.date)),
                    StreamBuilder<List<BillPeopleData>>(
                      stream: db.billsDao.watchBillPeopleForBill(bill.id),
                      builder: (context, snapshot) {
                        final billPeople = snapshot.data;
                        if (billPeople == null || billPeople.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: PaymentStatusBadge(status: PaymentStatus.fromBillPeople(billPeople)),
                        );
                      },
                    ),
                  ],
                ),
                trailing: Text(currency.format(bill.total)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)),
                  );
                },
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
