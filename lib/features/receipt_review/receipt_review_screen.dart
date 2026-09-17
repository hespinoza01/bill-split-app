import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/parsed_receipt.dart';
import '../assignment/people_selection_screen.dart';
import '../assignment/reviewed_bill_data.dart';
import 'receipt_review_view_model.dart';

/// Fase 3: revisión/edición del resultado del parseo (local o Gemini) antes
/// de continuar. El parseo automático a veces se equivoca — este paso es la
/// mitigación principal, no un fix técnico del parseo en sí.
class ReceiptReviewScreen extends StatelessWidget {
  final ParsedReceipt parsed;

  const ReceiptReviewScreen({super.key, required this.parsed});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReceiptReviewViewModel.fromParsed(parsed),
      child: const _ReviewBody(),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReceiptReviewViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar factura')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.hasReconciliationMismatch)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los números no cuadran exactamente. Revisa ítems, subtotal, impuesto y propina.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Text('Ítems', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(vm.items.length, (i) => _ItemRow(index: i)),
          TextButton.icon(
            onPressed: vm.addEmptyItem,
            icon: const Icon(Icons.add),
            label: const Text('Agregar ítem'),
          ),
          const Divider(height: 32),
          _TotalsFields(vm: vm),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: vm.items.isEmpty
                ? null
                : () {
                    final reviewed = ReviewedBillData(
                      restaurantName: vm.restaurantName,
                      items: vm.items
                          .map((i) => BillLineItemSummary(name: i.name, lineTotal: i.lineTotal))
                          .toList(),
                      subtotal: vm.subtotal,
                      tax: vm.tax,
                      tip: vm.tip,
                      total: vm.total,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PeopleSelectionScreen(bill: reviewed)),
                    );
                  },
            child: Text(vm.items.isEmpty ? 'Agrega al menos un ítem para continuar' : 'Continuar'),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  const _ItemRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReceiptReviewViewModel>();
    final item = context.watch<ReceiptReviewViewModel>().items[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: item.name,
                decoration: const InputDecoration(labelText: 'Nombre', isDense: true),
                onChanged: (v) => vm.updateItem(index, name: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: item.lineTotal.toStringAsFixed(2),
                decoration: const InputDecoration(labelText: 'Precio', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => vm.updateItem(index, lineTotal: double.tryParse(v) ?? item.lineTotal),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => vm.removeItem(index),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsFields extends StatelessWidget {
  final ReceiptReviewViewModel vm;
  const _TotalsFields({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TotalField(label: 'Subtotal', value: vm.subtotal, onChanged: (v) => vm.updateTotals(subtotal: v)),
        _TotalField(label: 'Impuesto', value: vm.tax, onChanged: (v) => vm.updateTotals(tax: v)),
        _TotalField(label: 'Propina', value: vm.tip, onChanged: (v) => vm.updateTotals(tip: v)),
        _TotalField(label: 'Total', value: vm.total, onChanged: (v) => vm.updateTotals(total: v)),
      ],
    );
  }
}

class _TotalField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _TotalField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value.toStringAsFixed(2),
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => onChanged(double.tryParse(v) ?? value),
      ),
    );
  }
}
