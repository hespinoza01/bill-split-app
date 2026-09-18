import 'package:flutter/foundation.dart';

import '../../data/models/parsed_receipt.dart';

class EditableLineItem {
  static int _nextId = 0;

  /// Identidad estable de este ítem en la sesión de edición — no viene de
  /// la DB (todavía no se guardó nada). Sirve de `Key` para la fila en la
  /// UI, así Flutter no reusa por error el widget/estado de un ítem viejo
  /// cuando la lista cambia de tamaño (ej. al dividir uno en unidades).
  final int id;

  String name;
  double quantity;
  double unitPrice;
  double lineTotal;

  EditableLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  }) : id = _nextId++;

  factory EditableLineItem.fromParsed(ParsedLineItem p) {
    return EditableLineItem(name: p.name, quantity: p.quantity, unitPrice: p.unitPrice, lineTotal: p.lineTotal);
  }
}

/// Config de un cargo (impuesto o propina) — se puede ingresar como monto
/// fijo o como porcentaje del subtotal, y se puede desactivar del todo
/// (factura sin ese cargo). Guarda ambos valores (monto y porcentaje) para
/// no perder lo que el usuario ya escribió al cambiar de modo.
class ChargeConfig {
  bool enabled;
  bool isPercent;
  double amount;
  double percent;

  ChargeConfig({required this.enabled, required this.isPercent, required this.amount, required this.percent});

  /// El monto efectivo en dólares, según el modo y si está habilitado.
  double effectiveAmount(double subtotal) {
    if (!enabled) return 0;
    return isPercent ? subtotal * percent / 100 : amount;
  }
}

/// Holds the editable state for the Receipt Review screen. The user can
/// correct anything the parser (local or Gemini) got wrong before saving —
/// this correction step is the main mitigation for OCR/LLM parsing errors.
class ReceiptReviewViewModel extends ChangeNotifier {
  String? restaurantName;
  final List<EditableLineItem> items;
  // Se pone en true si se agrega/borra/divide un ítem — eso corre los
  // índices de la lista. Si esto pasa durante una edición de factura ya
  // guardada, las asignaciones precargadas (que vienen mapeadas por índice)
  // quedarían apuntando al ítem equivocado, asignando plata a la persona
  // que no es sin ningún error visible. El screen usa esta bandera pa
  // descartar la precarga de asignaciones en ese caso.
  bool itemsStructureChanged = false;
  double subtotal;
  ChargeConfig taxConfig;
  ChargeConfig tipConfig;
  double total;

  ReceiptReviewViewModel.fromParsed(ParsedReceipt parsed)
      : restaurantName = parsed.restaurantName,
        items = parsed.items.map(EditableLineItem.fromParsed).toList(),
        subtotal = parsed.subtotal,
        taxConfig = ChargeConfig(enabled: true, isPercent: false, amount: parsed.tax, percent: 0),
        tipConfig = ChargeConfig(enabled: true, isPercent: false, amount: parsed.tip, percent: 0),
        total = parsed.total;

  double get tax => taxConfig.effectiveAmount(subtotal);
  double get tip => tipConfig.effectiveAmount(subtotal);

  double get itemsSum => items.fold(0, (sum, i) => sum + i.lineTotal);

  /// Non-blocking sanity check: warns when the edited numbers don't add up,
  /// since receipts themselves sometimes have rounding discrepancies.
  bool get hasReconciliationMismatch {
    final expectedTotal = subtotal + tax + tip;
    return (itemsSum - subtotal).abs() > 0.05 || (expectedTotal - total).abs() > 0.05;
  }

  void addEmptyItem() {
    items.add(EditableLineItem(name: '', quantity: 1, unitPrice: 0, lineTotal: 0));
    itemsStructureChanged = true;
    notifyListeners();
  }

  void removeItem(int index) {
    items.removeAt(index);
    itemsStructureChanged = true;
    notifyListeners();
  }

  /// Convierte un ítem con cantidad >1 (ej. "Refresco x4 — $10.00") en N
  /// tarjetas independientes de 1 unidad c/u — así cada una se puede asignar
  /// a una persona distinta en vez de forzar un reparto parejo entre todos
  /// los que se marquen. Reparte los centavos exactos (el resto va a las
  /// primeras unidades) para que la suma nunca quede desfasada del total
  /// original del ítem.
  void splitItemIntoUnits(int index) {
    final item = items[index];
    final qty = item.quantity.round();
    if (qty <= 1) return;

    final totalCents = (item.lineTotal * 100).round();
    final baseCents = totalCents ~/ qty;
    final remainderCents = totalCents - baseCents * qty;

    final units = List.generate(qty, (i) {
      final cents = baseCents + (i < remainderCents ? 1 : 0);
      return EditableLineItem(name: item.name, quantity: 1, unitPrice: cents / 100, lineTotal: cents / 100);
    });

    items.removeAt(index);
    items.insertAll(index, units);
    itemsStructureChanged = true;
    notifyListeners();
  }

  void updateItem(int index, {String? name, double? quantity, double? unitPrice, double? lineTotal}) {
    final item = items[index];
    if (name != null) item.name = name;
    if (quantity != null) item.quantity = _nonNegative(quantity);
    if (unitPrice != null) item.unitPrice = _nonNegative(unitPrice);
    if (lineTotal != null) item.lineTotal = _nonNegative(lineTotal);
    notifyListeners();
  }

  void updateRestaurantName(String value) {
    restaurantName = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }

  void updateSubtotal(double value) {
    subtotal = _nonNegative(value);
    notifyListeners();
  }

  void updateTotal(double value) {
    total = _nonNegative(value);
    notifyListeners();
  }

  void setTaxEnabled(bool enabled) {
    taxConfig.enabled = enabled;
    notifyListeners();
  }

  void setTaxIsPercent(bool isPercent) {
    taxConfig.isPercent = isPercent;
    notifyListeners();
  }

  void setTaxAmount(double value) {
    taxConfig.amount = _nonNegative(value);
    notifyListeners();
  }

  void setTaxPercent(double value) {
    taxConfig.percent = _nonNegative(value);
    notifyListeners();
  }

  void setTipEnabled(bool enabled) {
    tipConfig.enabled = enabled;
    notifyListeners();
  }

  void setTipIsPercent(bool isPercent) {
    tipConfig.isPercent = isPercent;
    notifyListeners();
  }

  void setTipAmount(double value) {
    tipConfig.amount = _nonNegative(value);
    notifyListeners();
  }

  void setTipPercent(double value) {
    tipConfig.percent = _nonNegative(value);
    notifyListeners();
  }

  // Un precio o monto negativo no tiene sentido en una factura — se le
  // pide al usuario un valor válido en vez de dejar que el cálculo de
  // reparto arrastre números negativos silenciosamente.
  double _nonNegative(double value) => value < 0 ? 0 : value;
}
