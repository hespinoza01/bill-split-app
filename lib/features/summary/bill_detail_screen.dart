import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../assignment/reviewed_bill_data.dart';
import '../../services/share_service.dart';
import 'person_total_card.dart';
import 'split_calculator.dart';

/// Vista de solo lectura de una factura ya guardada — reconstruye el mismo
/// reparto por persona que se vio al guardarla, a partir de lo persistido
/// (no hay edición acá, esa ventana ya pasó).
class BillDetailScreen extends StatelessWidget {
  final int billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: const Text('Factura')),
      body: FutureBuilder<_BillDetailData>(
        future: _loadBillDetail(db, billId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar la factura: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final shareService = ShareService();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.personTotals.length,
            itemBuilder: (context, index) => PersonTotalCard(
              personTotal: data.personTotals[index],
              onShare: () => shareService.sharePersonTotal(data.personTotals[index], data.bill),
            ),
          );
        },
      ),
    );
  }

  Future<_BillDetailData> _loadBillDetail(AppDatabase db, int billId) async {
    final bill = await db.billsDao.getBill(billId);
    final lineItems = await db.billsDao.lineItemsForBill(billId);
    final billPeople = await db.billsDao.billPeopleForBill(billId);
    final assignments = await db.billsDao.assignmentsForLineItems(lineItems.map((i) => i.id).toList());
    final allPeople = await db.peopleDao.watchAllPeople().first;

    final personIdByBillPersonId = {for (final bp in billPeople) bp.id: bp.personId};
    final personIds = billPeople.map((bp) => bp.personId).toSet();
    final people = allPeople.where((p) => personIds.contains(p.id)).toList();

    // LineItems no garantizan el mismo orden en que se guardaron — se
    // ordenan por id para que la posición sea estable y coincida con los
    // índices usados en assignmentsByItemIndex.
    lineItems.sort((a, b) => a.id.compareTo(b.id));

    final assignmentsByItemIndex = <int, Set<int>>{};
    for (var i = 0; i < lineItems.length; i++) {
      final itemAssignments = assignments.where((a) => a.lineItemId == lineItems[i].id);
      assignmentsByItemIndex[i] = itemAssignments
          .map((a) => personIdByBillPersonId[a.billPersonId])
          .whereType<int>()
          .toSet();
    }

    final reviewedBill = ReviewedBillData(
      restaurantName: bill.restaurantName,
      items: lineItems.map((i) => BillLineItemSummary(name: i.name, lineTotal: i.lineTotal)).toList(),
      subtotal: bill.subtotal,
      tax: bill.taxAmount,
      tip: bill.tipAmount,
      total: bill.total,
    );

    final personTotals = calculateSplit(
      bill: reviewedBill,
      people: people,
      assignmentsByItemIndex: assignmentsByItemIndex,
    );

    return _BillDetailData(bill: reviewedBill, personTotals: personTotals);
  }
}

class _BillDetailData {
  final ReviewedBillData bill;
  final List<PersonTotal> personTotals;
  _BillDetailData({required this.bill, required this.personTotals});
}
