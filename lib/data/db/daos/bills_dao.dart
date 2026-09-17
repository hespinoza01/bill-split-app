import 'package:drift/drift.dart';

import '../app_database.dart';

part 'bills_dao.g.dart';

@DriftAccessor(tables: [Bills, LineItems, BillPeople, Assignments])
class BillsDao extends DatabaseAccessor<AppDatabase> with _$BillsDaoMixin {
  BillsDao(super.db);

  Stream<List<Bill>> watchAllBills() {
    return (select(bills)
          ..where((b) => b.status.equalsValue(BillStatus.finalized))
          ..orderBy([(b) => OrderingTerm.desc(b.date)]))
        .watch();
  }

  Future<Bill> getBill(int id) => (select(bills)..where((b) => b.id.equals(id))).getSingle();

  Future<List<LineItem>> lineItemsForBill(int billId) {
    return (select(lineItems)..where((li) => li.billId.equals(billId))).get();
  }

  Future<List<BillPeopleData>> billPeopleForBill(int billId) {
    return (select(billPeople)..where((bp) => bp.billId.equals(billId))).get();
  }

  Future<List<Assignment>> assignmentsForLineItems(List<int> lineItemIds) {
    return (select(assignments)..where((a) => a.lineItemId.isIn(lineItemIds))).get();
  }

  Future<int> insertDraftBill() => into(bills).insert(BillsCompanion.insert());

  // Fase 1 debug affordance: prueba que la DB persiste entre hot restarts.
  // Se reemplaza por el flujo real (Capture -> OCR -> Gemini -> Review -> Save) en Fase 5.
  Future<int> debugInsertFinalizedBill() {
    return into(bills).insert(
      BillsCompanion.insert(
        restaurantName: const Value('Restaurante de prueba'),
        total: const Value(42.50),
        status: const Value(BillStatus.finalized),
      ),
    );
  }

  Future<void> saveFullBill({
    required int billId,
    required BillsCompanion billUpdate,
    required List<LineItemsCompanion> lineItemRows,
    required List<int> personIds,
    required Map<int, List<int>> assignmentsByLocalItemIndex,
  }) async {
    await transaction(() async {
      await (update(bills)..where((b) => b.id.equals(billId))).write(billUpdate);

      await (delete(lineItems)..where((li) => li.billId.equals(billId))).go();
      await (delete(billPeople)..where((bp) => bp.billId.equals(billId))).go();

      final insertedItemIds = <int>[];
      for (final row in lineItemRows) {
        final id = await into(lineItems).insert(row.copyWith(billId: Value(billId)));
        insertedItemIds.add(id);
      }

      final billPersonIdByPersonId = <int, int>{};
      for (final personId in personIds) {
        final bpId = await into(billPeople).insert(
          BillPeopleCompanion.insert(billId: billId, personId: personId),
        );
        billPersonIdByPersonId[personId] = bpId;
      }

      for (final entry in assignmentsByLocalItemIndex.entries) {
        final lineItemId = insertedItemIds[entry.key];
        for (final personId in entry.value) {
          final billPersonId = billPersonIdByPersonId[personId];
          if (billPersonId == null) continue;
          await into(assignments).insert(
            AssignmentsCompanion.insert(lineItemId: lineItemId, billPersonId: billPersonId),
          );
        }
      }

      await (update(bills)..where((b) => b.id.equals(billId)))
          .write(const BillsCompanion(status: Value(BillStatus.finalized)));
    });
  }

  Future<void> deleteBill(int billId) => (delete(bills)..where((b) => b.id.equals(billId))).go();
}
