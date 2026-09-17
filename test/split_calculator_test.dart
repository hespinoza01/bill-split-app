import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split_app/data/db/app_database.dart';
import 'package:bill_split_app/features/assignment/reviewed_bill_data.dart';
import 'package:bill_split_app/features/summary/split_calculator.dart';

PeopleData _person(int id, String name) {
  return PeopleData(id: id, name: name, avatarInitials: name[0], createdAt: DateTime(2026));
}

void main() {
  test('divide un ítem compartido entre 3 personas y reparte tax/tip proporcional', () {
    // 3 personas, 1 ítem compartido de $30, 10% tax, 15% tip sobre ese subtotal.
    final people = [_person(1, 'Ana'), _person(2, 'Beto'), _person(3, 'Caro')];
    final bill = ReviewedBillData(
      restaurantName: 'Test',
      items: [BillLineItemSummary(name: 'Plato compartido', lineTotal: 30)],
      subtotal: 30,
      tax: 3, // 10%
      tip: 4.5, // 15%
      total: 37.5,
    );
    final assignments = {0: {1, 2, 3}};

    final result = calculateSplit(bill: bill, people: people, assignmentsByItemIndex: assignments);

    expect(result.length, 3);
    for (final personTotal in result) {
      expect(personTotal.subtotalShare, closeTo(10, 0.001));
      expect(personTotal.taxShare, closeTo(1, 0.001));
      expect(personTotal.tipShare, closeTo(1.5, 0.001));
      expect(personTotal.total, closeTo(12.5, 0.001));
    }

    final sumOfTotals = result.fold(0.0, (sum, p) => sum + p.total);
    expect(sumOfTotals, closeTo(bill.total, 0.001));
  });

  test('ítems individuales dan cuenta distinta a cada quien, proporcional al consumo', () {
    final people = [_person(1, 'Ana'), _person(2, 'Beto')];
    final bill = ReviewedBillData(
      restaurantName: null,
      items: [
        BillLineItemSummary(name: 'Caro', lineTotal: 20), // solo Ana
        BillLineItemSummary(name: 'Barato', lineTotal: 5), // solo Beto
      ],
      subtotal: 25,
      tax: 2.5, // 10%
      tip: 0,
      total: 27.5,
    );
    final assignments = {0: {1}, 1: {2}};

    final result = calculateSplit(bill: bill, people: people, assignmentsByItemIndex: assignments);

    final ana = result.firstWhere((p) => p.person.id == 1);
    final beto = result.firstWhere((p) => p.person.id == 2);

    expect(ana.subtotalShare, closeTo(20, 0.001));
    expect(ana.taxShare, closeTo(2, 0.001)); // 20/25 * 2.5
    expect(ana.total, closeTo(22, 0.001));

    expect(beto.subtotalShare, closeTo(5, 0.001));
    expect(beto.taxShare, closeTo(0.5, 0.001)); // 5/25 * 2.5
    expect(beto.total, closeTo(5.5, 0.001));
  });
}
