import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../assignment/reviewed_bill_data.dart';
import '../../services/share_service.dart';
import 'person_total_card.dart';
import 'split_calculator.dart';

/// Fase 5: resumen final — cuánto le toca pagar a cada persona, con botón
/// pa compartirle el detalle, y "Guardar" que persiste la factura completa
/// (ítems, personas, asignaciones) en el historial.
class SummaryScreen extends StatefulWidget {
  final ReviewedBillData bill;
  final List<PeopleData> people;
  final Map<int, Set<int>> assignmentsByItemIndex;

  const SummaryScreen({
    super.key,
    required this.bill,
    required this.people,
    required this.assignmentsByItemIndex,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _shareService = ShareService();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final personTotals = calculateSplit(
      bill: widget.bill,
      people: widget.people,
      assignmentsByItemIndex: widget.assignmentsByItemIndex,
    );
    final currency = NumberFormat.simpleCurrency();
    final sumOfTotals = personTotals.fold(0.0, (sum, p) => sum + p.total);
    final mismatch = (sumOfTotals - widget.bill.total).abs() > 0.05;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: Column(
        children: [
          if (mismatch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade100,
              child: Text(
                'La suma de lo que le toca a cada quien (${currency.format(sumOfTotals)}) no coincide '
                'exactamente con el total de la factura (${currency.format(widget.bill.total)}). '
                'Puede ser redondeo, o algo quedó mal en la revisión.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: personTotals.length,
              itemBuilder: (context, index) => PersonTotalCard(
                personTotal: personTotals[index],
                onShare: () => _shareService.sharePersonTotal(personTotals[index], widget.bill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving ? null : () => _saveBill(personTotals),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar factura'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBill(List<PersonTotal> personTotals) async {
    setState(() => _saving = true);
    final db = context.read<AppDatabase>();
    final navigator = Navigator.of(context);
    try {
      final billId = await db.billsDao.insertDraftBill();

      final lineItemRows = widget.bill.items
          .map((i) => LineItemsCompanion.insert(
                billId: billId,
                name: i.name,
                unitPrice: i.lineTotal,
                lineTotal: i.lineTotal,
              ))
          .toList();

      final assignmentsByIndex = <int, List<int>>{
        for (final entry in widget.assignmentsByItemIndex.entries) entry.key: entry.value.toList(),
      };

      await db.billsDao.saveFullBill(
        billId: billId,
        billUpdate: BillsCompanion(
          restaurantName: Value(widget.bill.restaurantName),
          subtotal: Value(widget.bill.subtotal),
          taxAmount: Value(widget.bill.tax),
          tipAmount: Value(widget.bill.tip),
          total: Value(widget.bill.total),
        ),
        lineItemRows: lineItemRows,
        personIds: widget.people.map((p) => p.id).toList(),
        assignmentsByLocalItemIndex: assignmentsByIndex,
      );

      navigator.popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
