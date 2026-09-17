import 'package:flutter_test/flutter_test.dart';

import 'package:bill_split_app/data/models/parsed_receipt.dart';
import 'package:bill_split_app/features/receipt_review/receipt_review_view_model.dart';

void main() {
  group('splitItemIntoUnits', () {
    test('reparte un total exacto entre unidades sin resto', () {
      final vm = ReceiptReviewViewModel.fromParsed(ParsedReceipt(
        items: [ParsedLineItem(name: 'Refresco cola', quantity: 4, unitPrice: 2.5, lineTotal: 10.0)],
        subtotal: 10,
        tax: 0,
        tip: 0,
        total: 10,
      ));

      vm.splitItemIntoUnits(0);

      expect(vm.items.length, 4);
      for (final item in vm.items) {
        expect(item.name, 'Refresco cola');
        expect(item.quantity, 1);
        expect(item.lineTotal, closeTo(2.5, 0.001));
      }
      expect(vm.items.fold(0.0, (sum, i) => sum + i.lineTotal), closeTo(10.0, 0.001));
    });

    test('reparte el resto de centavos sin perder ni un centavo del total', () {
      // $10.00 entre 3 unidades = $3.333... -> 2 unidades de $3.34 + 1 de $3.32,
      // o combinacion equivalente que sume exacto a $10.00.
      final vm = ReceiptReviewViewModel.fromParsed(ParsedReceipt(
        items: [ParsedLineItem(name: 'Cerveza', quantity: 3, unitPrice: 3.33, lineTotal: 10.0)],
        subtotal: 10,
        tax: 0,
        tip: 0,
        total: 10,
      ));

      vm.splitItemIntoUnits(0);

      expect(vm.items.length, 3);
      final totalCents = vm.items.fold(0, (sum, i) => sum + (i.lineTotal * 100).round());
      expect(totalCents, 1000); // $10.00 exacto, sin drift de redondeo
    });

    test('no hace nada si la cantidad ya es 1', () {
      final vm = ReceiptReviewViewModel.fromParsed(ParsedReceipt(
        items: [ParsedLineItem(name: 'Café', quantity: 1, unitPrice: 2.0, lineTotal: 2.0)],
        subtotal: 2,
        tax: 0,
        tip: 0,
        total: 2,
      ));

      vm.splitItemIntoUnits(0);

      expect(vm.items.length, 1);
    });
  });
}
