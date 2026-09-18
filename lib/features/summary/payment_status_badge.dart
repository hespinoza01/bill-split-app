import 'package:flutter/material.dart';

import 'payment_status.dart';

/// Chip compacto "Parcial 2/4" — reusado en la lista de facturas y en el
/// detalle de una factura guardada.
class PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const PaymentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status.status) {
      BillPaymentStatus.pending => (Icons.hourglass_empty, Colors.orange),
      BillPaymentStatus.partial => (Icons.incomplete_circle, Colors.blue),
      BillPaymentStatus.paid => (Icons.check_circle, Colors.green),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text('${status.label} ${status.paidCount}/${status.totalCount}'),
      labelStyle: const TextStyle(fontSize: 12),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
