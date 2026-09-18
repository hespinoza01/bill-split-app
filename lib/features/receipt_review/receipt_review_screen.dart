import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  // Presentes solo cuando se llegó acá desde "Editar" en una factura ya
  // guardada (BillDetailScreen) — viajan sin tocarse hasta SummaryScreen
  // (editingBillId, pa actualizar en vez de crear) y hasta
  // PeopleSelectionScreen/AssignmentScreen (los otros dos, pa precargar la
  // selección de personas y las asignaciones ya hechas).
  final int? editingBillId;
  final Set<int>? initialSelectedPersonIds;
  final Map<int, Set<int>>? initialAssignmentsByItemIndex;

  const ReceiptReviewScreen({
    super.key,
    required this.parsed,
    this.editingBillId,
    this.initialSelectedPersonIds,
    this.initialAssignmentsByItemIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReceiptReviewViewModel.fromParsed(parsed),
      child: _ReviewBody(
        editingBillId: editingBillId,
        initialSelectedPersonIds: initialSelectedPersonIds,
        initialAssignmentsByItemIndex: initialAssignmentsByItemIndex,
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  final int? editingBillId;
  final Set<int>? initialSelectedPersonIds;
  final Map<int, Set<int>>? initialAssignmentsByItemIndex;

  const _ReviewBody({
    this.editingBillId,
    this.initialSelectedPersonIds,
    this.initialAssignmentsByItemIndex,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReceiptReviewViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar factura')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            initialValue: vm.restaurantName ?? '',
            decoration: const InputDecoration(labelText: 'Nombre del lugar (opcional)', isDense: true),
            onChanged: vm.updateRestaurantName,
          ),
          const SizedBox(height: 16),
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
          ...List.generate(vm.items.length, (i) => _ItemRow(key: ValueKey(vm.items[i].id), index: i)),
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
                      MaterialPageRoute(
                        builder: (_) => PeopleSelectionScreen(
                          bill: reviewed,
                          editingBillId: editingBillId,
                          initialSelectedPersonIds: initialSelectedPersonIds,
                          // Si se agregó/borró/dividió algún ítem, los índices
                          // ya no coinciden con los de la factura guardada —
                          // se descarta la precarga en vez de arriesgar
                          // asignar plata a la persona equivocada sin avisar.
                          initialAssignmentsByItemIndex:
                              vm.itemsStructureChanged ? null : initialAssignmentsByItemIndex,
                        ),
                      ),
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
  const _ItemRow({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ReceiptReviewViewModel>();
    final item = context.watch<ReceiptReviewViewModel>().items[index];
    final qty = item.quantity.round();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                SizedBox(
                  width: 64,
                  child: TextFormField(
                    initialValue: qty.toString(),
                    decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => vm.updateItem(index, quantity: double.tryParse(v) ?? item.quantity),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item.lineTotal.toStringAsFixed(2),
                    decoration: const InputDecoration(labelText: 'Precio total', isDense: true),
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
            if (qty > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Son $qty unidades. Si cada persona consumió una distinta, divídelo para asignarlas por separado.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () => vm.splitItemIntoUnits(index),
                      child: const Text('Dividir'),
                    ),
                  ],
                ),
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
        _TotalField(label: 'Subtotal', value: vm.subtotal, onChanged: vm.updateSubtotal),
        const SizedBox(height: 8),
        _ChargeField(
          label: 'Impuesto',
          noneLabel: 'Sin impuesto en esta factura',
          config: vm.taxConfig,
          subtotal: vm.subtotal,
          onEnabledChanged: vm.setTaxEnabled,
          onModeChanged: vm.setTaxIsPercent,
          onAmountChanged: vm.setTaxAmount,
          onPercentChanged: vm.setTaxPercent,
        ),
        const SizedBox(height: 8),
        _ChargeField(
          label: 'Propina',
          noneLabel: 'Sin propina en esta factura',
          config: vm.tipConfig,
          subtotal: vm.subtotal,
          onEnabledChanged: vm.setTipEnabled,
          onModeChanged: vm.setTipIsPercent,
          onAmountChanged: vm.setTipAmount,
          onPercentChanged: vm.setTipPercent,
        ),
        const SizedBox(height: 8),
        _TotalField(label: 'Total', value: vm.total, onChanged: vm.updateTotal),
      ],
    );
  }
}

/// Campo de impuesto o propina: se puede desactivar del todo (factura sin
/// ese cargo), o ingresar como monto fijo en dólares o como porcentaje del
/// subtotal — mostrando siempre el monto en dólares equivalente.
class _ChargeField extends StatelessWidget {
  final String label;
  final String noneLabel;
  final ChargeConfig config;
  final double subtotal;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<double> onPercentChanged;

  const _ChargeField({
    required this.label,
    required this.noneLabel,
    required this.config,
    required this.subtotal,
    required this.onEnabledChanged,
    required this.onModeChanged,
    required this.onAmountChanged,
    required this.onPercentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: !config.enabled,
              title: Text(noneLabel, style: const TextStyle(fontSize: 13)),
              onChanged: (checked) => onEnabledChanged(!(checked ?? false)),
            ),
            if (config.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Row(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('\$')),
                        ButtonSegment(value: true, label: Text('%')),
                      ],
                      selected: {config.isPercent},
                      onSelectionChanged: (selection) => onModeChanged(selection.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: config.isPercent
                          ? TextFormField(
                              key: ValueKey('$label-percent-${config.percent}'),
                              initialValue: config.percent.toStringAsFixed(1),
                              decoration: InputDecoration(
                                labelText: '$label (%)',
                                isDense: true,
                                helperText: '= ${NumberFormat.simpleCurrency().format(config.effectiveAmount(subtotal))}',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => onPercentChanged(double.tryParse(v) ?? config.percent),
                            )
                          : TextFormField(
                              key: ValueKey('$label-amount-${config.amount}'),
                              initialValue: config.amount.toStringAsFixed(2),
                              decoration: InputDecoration(labelText: label, isDense: true),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => onAmountChanged(double.tryParse(v) ?? config.amount),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
