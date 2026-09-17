import 'package:flutter/foundation.dart';

import '../../data/models/parsed_receipt.dart';

class EditableLineItem {
  String name;
  double quantity;
  double unitPrice;
  double lineTotal;

  EditableLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory EditableLineItem.fromParsed(ParsedLineItem p) {
    return EditableLineItem(name: p.name, quantity: p.quantity, unitPrice: p.unitPrice, lineTotal: p.lineTotal);
  }
}

/// Holds the editable state for the Receipt Review screen. The user can
/// correct anything the parser (local or Gemini) got wrong before saving —
/// this correction step is the main mitigation for OCR/LLM parsing errors.
class ReceiptReviewViewModel extends ChangeNotifier {
  String? restaurantName;
  final List<EditableLineItem> items;
  double subtotal;
  double tax;
  double tip;
  double total;

  ReceiptReviewViewModel.fromParsed(ParsedReceipt parsed)
      : restaurantName = parsed.restaurantName,
        items = parsed.items.map(EditableLineItem.fromParsed).toList(),
        subtotal = parsed.subtotal,
        tax = parsed.tax,
        tip = parsed.tip,
        total = parsed.total;

  double get itemsSum => items.fold(0, (sum, i) => sum + i.lineTotal);

  /// Non-blocking sanity check: warns when the edited numbers don't add up,
  /// since receipts themselves sometimes have rounding discrepancies.
  bool get hasReconciliationMismatch {
    final expectedTotal = subtotal + tax + tip;
    return (itemsSum - subtotal).abs() > 0.05 || (expectedTotal - total).abs() > 0.05;
  }

  void addEmptyItem() {
    items.add(EditableLineItem(name: '', quantity: 1, unitPrice: 0, lineTotal: 0));
    notifyListeners();
  }

  void removeItem(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  void updateItem(int index, {String? name, double? quantity, double? unitPrice, double? lineTotal}) {
    final item = items[index];
    if (name != null) item.name = name;
    if (quantity != null) item.quantity = quantity;
    if (unitPrice != null) item.unitPrice = unitPrice;
    if (lineTotal != null) item.lineTotal = lineTotal;
    notifyListeners();
  }

  void updateTotals({double? subtotal, double? tax, double? tip, double? total}) {
    if (subtotal != null) this.subtotal = subtotal;
    if (tax != null) this.tax = tax;
    if (tip != null) this.tip = tip;
    if (total != null) this.total = total;
    notifyListeners();
  }
}
