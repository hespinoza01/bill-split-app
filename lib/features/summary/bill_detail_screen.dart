import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../../data/models/parsed_receipt.dart';
import '../assignment/reviewed_bill_data.dart';
import '../receipt_review/receipt_review_screen.dart';
import '../../services/share_service.dart';
import 'full_bill_view.dart';
import 'person_total_card.dart';
import 'split_calculator.dart';

/// Vista de una factura ya guardada — reconstruye el mismo reparto por
/// persona que se vio al guardarla, a partir de lo persistido. Permite
/// marcar quién ya pagó (isPaid vive en BillPeople) y, vía "Editar", volver
/// a entrar al mismo flujo de revisión/asignación con todo precargado.
class BillDetailScreen extends StatefulWidget {
  final int billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late Future<_BillDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadBillDetail(context.read<AppDatabase>(), widget.billId);
  }

  void _reload() {
    setState(() {
      _detailFuture = _loadBillDetail(context.read<AppDatabase>(), widget.billId);
    });
  }

  Future<void> _togglePaid(_BillDetailData data, int personId, bool paid) async {
    final billPersonId = data.billPersonIdByPersonId[personId];
    if (billPersonId == null) return;
    final db = context.read<AppDatabase>();
    final previous = data.isPaidByPersonId[personId];
    // Optimista: refleja el cambio en la UI ya mismo, sin esperar la DB ni
    // recargar toda la pantalla. Si el write falla, se revierte y se avisa
    // — si no, el chip quedaría mostrando un estado que nunca se guardó.
    setState(() => data.isPaidByPersonId[personId] = paid);
    try {
      await db.billsDao.setBillPersonPaid(billPersonId, paid);
    } catch (e) {
      if (!mounted) return;
      setState(() => data.isPaidByPersonId[personId] = previous ?? !paid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cambio: $e')),
      );
    }
  }

  Future<void> _editBill(_BillDetailData data) async {
    final bill = data.bill;
    final parsed = ParsedReceipt(
      restaurantName: bill.restaurantName,
      items: bill.items
          .map((i) => ParsedLineItem(name: i.name, quantity: 1, unitPrice: i.lineTotal, lineTotal: i.lineTotal))
          .toList(),
      subtotal: bill.subtotal,
      tax: bill.tax,
      tip: bill.tip,
      total: bill.total,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(
          parsed: parsed,
          editingBillId: widget.billId,
          initialSelectedPersonIds: data.selectedPersonIds,
          initialAssignmentsByItemIndex: data.assignmentsByItemIndex,
        ),
      ),
    );
    // Al volver de editar (guardado o no), recarga por si cambió algo — el
    // flujo de edición hace popUntil(isFirst), así que en la práctica esto
    // corre recién cuando se reabre esta pantalla desde el historial, pero
    // no cuesta nada dejarlo por si el usuario vuelve con el botón atrás.
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Factura'),
          actions: [
            FutureBuilder<_BillDetailData>(
              future: _detailFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar',
                  onPressed: () => _editBill(snapshot.data!),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Por persona'), Tab(text: 'Factura completa')],
          ),
        ),
        body: FutureBuilder<_BillDetailData>(
          future: _detailFuture,
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
            return TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.personTotals.length,
                  itemBuilder: (context, index) {
                    final personTotal = data.personTotals[index];
                    return PersonTotalCard(
                      personTotal: personTotal,
                      onShare: () => shareService.sharePersonTotal(personTotal, data.bill),
                      isPaid: data.isPaidByPersonId[personTotal.person.id],
                      onPaidChanged: (paid) => _togglePaid(data, personTotal.person.id, paid),
                    );
                  },
                ),
                FullBillView(bill: data.bill),
              ],
            );
          },
        ),
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
    final billPersonIdByPersonId = {for (final bp in billPeople) bp.personId: bp.id};
    final isPaidByPersonId = {for (final bp in billPeople) bp.personId: bp.isPaid};
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

    return _BillDetailData(
      bill: reviewedBill,
      personTotals: personTotals,
      selectedPersonIds: personIds,
      assignmentsByItemIndex: assignmentsByItemIndex,
      billPersonIdByPersonId: billPersonIdByPersonId,
      isPaidByPersonId: isPaidByPersonId,
    );
  }
}

class _BillDetailData {
  final ReviewedBillData bill;
  final List<PersonTotal> personTotals;
  final Set<int> selectedPersonIds;
  final Map<int, Set<int>> assignmentsByItemIndex;
  final Map<int, int> billPersonIdByPersonId;
  final Map<int, bool> isPaidByPersonId;

  _BillDetailData({
    required this.bill,
    required this.personTotals,
    required this.selectedPersonIds,
    required this.assignmentsByItemIndex,
    required this.billPersonIdByPersonId,
    required this.isPaidByPersonId,
  });
}
