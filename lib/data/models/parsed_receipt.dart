class ParsedLineItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  ParsedLineItem({
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ParsedLineItem.fromJson(Map<String, dynamic> json) {
    return ParsedLineItem(
      name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : 'Ítem sin nombre',
      quantity: _asDouble(json['quantity']) ?? 1,
      unitPrice: _asDouble(json['unitPrice']) ?? _asDouble(json['lineTotal']) ?? 0,
      lineTotal: _asDouble(json['lineTotal']) ?? 0,
    );
  }

  ParsedLineItem copyWith({String? name, double? quantity, double? unitPrice, double? lineTotal}) {
    return ParsedLineItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }
}

class ParsedReceipt {
  final String? restaurantName;
  final List<ParsedLineItem> items;
  final double subtotal;
  final double tax;
  final double tip;
  final double total;

  ParsedReceipt({
    this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.total,
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <ParsedLineItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) items.add(ParsedLineItem.fromJson(e));
      }
    }
    return ParsedReceipt(
      restaurantName: (json['restaurantName'] as String?)?.trim(),
      items: items,
      subtotal: _asDouble(json['subtotal']) ?? 0,
      tax: _asDouble(json['tax']) ?? 0,
      tip: _asDouble(json['tip']) ?? 0,
      total: _asDouble(json['total']) ?? 0,
    );
  }

  /// Empty receipt used as the manual-entry fallback when OCR/Gemini fail.
  factory ParsedReceipt.empty() {
    return ParsedReceipt(items: [], subtotal: 0, tax: 0, tip: 0, total: 0);
  }
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}
