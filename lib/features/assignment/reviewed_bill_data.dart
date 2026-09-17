/// Snapshot inmutable del resultado ya revisado/corregido en Receipt Review
/// — lo que viaja hacia selección de personas y asignación. Desacoplado del
/// ChangeNotifier editable de esa pantalla a propósito: acá los datos ya
/// están cerrados, no se vuelven a editar.
class BillLineItemSummary {
  final String name;
  final double lineTotal;

  BillLineItemSummary({required this.name, required this.lineTotal});
}

class ReviewedBillData {
  final String? restaurantName;
  final List<BillLineItemSummary> items;
  final double subtotal;
  final double tax;
  final double tip;
  final double total;

  ReviewedBillData({
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.total,
  });
}
