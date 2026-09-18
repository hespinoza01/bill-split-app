import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'split_calculator.dart';

/// Card de una persona con su desglose de ítems y total — reusado tanto en
/// el resumen recién calculado (Fase 5) como en la vista de solo lectura
/// de una factura ya guardada (historial, Fase 6).
class PersonTotalCard extends StatelessWidget {
  final PersonTotal personTotal;
  final VoidCallback onShare;
  // Solo se muestra el control de pagado/pendiente cuando onPaidChanged no es
  // null — en el resumen recién calculado (antes de guardar) nadie pagó
  // todavía, así que ese caso no pasa el callback y el chip no aparece.
  final bool? isPaid;
  final ValueChanged<bool>? onPaidChanged;

  const PersonTotalCard({
    super.key,
    required this.personTotal,
    required this.onShare,
    this.isPaid,
    this.onPaidChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(personTotal.person.avatarInitials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(personTotal.person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text(currency.format(personTotal.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            if (onPaidChanged != null)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 2),
                child: GestureDetector(
                  onTap: () => onPaidChanged!(!(isPaid ?? false)),
                  child: Chip(
                    avatar: Icon(
                      isPaid == true ? Icons.check_circle : Icons.hourglass_empty,
                      size: 16,
                      color: isPaid == true ? Colors.green : Colors.orange,
                    ),
                    label: Text(isPaid == true ? 'Pagó' : 'Pendiente'),
                    labelStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ...personTotal.items.map((item) {
              final sharedNote = item.sharedWithCount > 1 ? ' (compartido entre ${item.sharedWithCount})' : '';
              return Padding(
                padding: const EdgeInsets.only(left: 52, bottom: 2),
                child: Text('${item.itemName}$sharedNote — ${currency.format(item.shareAmount)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              );
            }),
            if (personTotal.taxShare > 0 || personTotal.tipShare > 0)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 4),
                child: Text(
                  'Impuesto: ${currency.format(personTotal.taxShare)} · Propina: ${currency.format(personTotal.tipShare)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
