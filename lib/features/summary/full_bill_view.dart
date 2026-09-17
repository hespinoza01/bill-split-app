import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../assignment/reviewed_bill_data.dart';

/// La factura completa tal cual, sin segmentar por persona — todos los
/// ítems con su precio real y los totales generales. Complementa la vista
/// "Por persona" para quien quiera ver el panorama completo de una sola vez.
class FullBillView extends StatelessWidget {
  final ReviewedBillData bill;

  const FullBillView({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final restaurant = bill.restaurantName?.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (restaurant != null && restaurant.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(restaurant, style: Theme.of(context).textTheme.titleLarge),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ítems', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...bill.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name)),
                        Text(currency.format(item.lineTotal)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _TotalRow(label: 'Subtotal', value: bill.subtotal, currency: currency),
                _TotalRow(label: 'Impuesto', value: bill.tax, currency: currency),
                _TotalRow(label: 'Propina', value: bill.tip, currency: currency),
                const Divider(height: 24),
                _TotalRow(label: 'Total', value: bill.total, currency: currency, bold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat currency;
  final bool bold;

  const _TotalRow({required this.label, required this.value, required this.currency, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(currency.format(value), style: style),
        ],
      ),
    );
  }
}
