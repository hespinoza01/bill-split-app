import '../../data/db/app_database.dart';
import '../assignment/reviewed_bill_data.dart';

/// Lo que le corresponde pagar a una persona: su parte de los ítems que
/// consumió, más su parte proporcional del impuesto y la propina según
/// cuánto representa su consumo del subtotal total de la factura.
class PersonTotal {
  final PeopleData person;
  final List<AssignedItemShare> items;
  final double subtotalShare;
  final double taxShare;
  final double tipShare;
  final double total;

  PersonTotal({
    required this.person,
    required this.items,
    required this.subtotalShare,
    required this.taxShare,
    required this.tipShare,
    required this.total,
  });
}

class AssignedItemShare {
  final String itemName;
  final double shareAmount;
  final int sharedWithCount;

  AssignedItemShare({required this.itemName, required this.shareAmount, required this.sharedWithCount});
}

/// Función pura: no toca la base de datos ni el estado de ningún widget —
/// solo aritmética, para que sea trivialmente testeable.
List<PersonTotal> calculateSplit({
  required ReviewedBillData bill,
  required List<PeopleData> people,
  required Map<int, Set<int>> assignmentsByItemIndex,
}) {
  final result = <PersonTotal>[];

  for (final person in people) {
    final items = <AssignedItemShare>[];
    var subtotalShare = 0.0;

    for (var i = 0; i < bill.items.length; i++) {
      final assignees = assignmentsByItemIndex[i] ?? const <int>{};
      if (!assignees.contains(person.id)) continue;

      final item = bill.items[i];
      final shareAmount = item.lineTotal / assignees.length;
      subtotalShare += shareAmount;
      items.add(AssignedItemShare(
        itemName: item.name,
        shareAmount: shareAmount,
        sharedWithCount: assignees.length,
      ));
    }

    // Evita división por cero si el subtotal de la factura quedó en 0
    // (caso borde: factura editada a mano sin completar montos).
    final proportion = bill.subtotal > 0 ? subtotalShare / bill.subtotal : 0.0;
    final taxShare = proportion * bill.tax;
    final tipShare = proportion * bill.tip;

    result.add(PersonTotal(
      person: person,
      items: items,
      subtotalShare: subtotalShare,
      taxShare: taxShare,
      tipShare: tipShare,
      total: subtotalShare + taxShare + tipShare,
    ));
  }

  return result;
}
