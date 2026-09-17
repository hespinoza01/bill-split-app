import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import 'assignment_view_model.dart';
import 'reviewed_bill_data.dart';

/// Fase 4: por cada ítem, marcar qué personas lo consumieron. Un ítem
/// compartido (ej. una entrada entre 3 personas) simplemente tiene varias
/// personas marcadas — la calculadora de Fase 5 divide su costo entre ellas.
class AssignmentScreen extends StatefulWidget {
  final ReviewedBillData bill;
  final List<int> personIds;

  const AssignmentScreen({super.key, required this.bill, required this.personIds});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  late Future<List<PeopleData>> _peopleFuture;

  @override
  void initState() {
    super.initState();
    final db = context.read<AppDatabase>();
    _peopleFuture = db.peopleDao.watchAllPeople().first.then(
          (all) => all.where((p) => widget.personIds.contains(p.id)).toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién consumió cada cosa?')),
      body: FutureBuilder<List<PeopleData>>(
        future: _peopleFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ChangeNotifierProvider(
            create: (_) => AssignmentViewModel(bill: widget.bill, people: snapshot.data!),
            child: const _AssignmentBody(),
          );
        },
      ),
    );
  }
}

class _AssignmentBody extends StatelessWidget {
  const _AssignmentBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();
    final currency = NumberFormat.simpleCurrency();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.bill.items.length,
            itemBuilder: (context, itemIndex) {
              final item = vm.bill.items[itemIndex];
              final hasAssignee = vm.assigneesFor(itemIndex).isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Text(currency.format(item.lineTotal)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: vm.people.map((person) {
                          final selected = vm.isAssigned(itemIndex, person.id);
                          return FilterChip(
                            avatar: CircleAvatar(child: Text(person.avatarInitials)),
                            label: Text(person.name),
                            selected: selected,
                            onSelected: (_) => vm.toggle(itemIndex, person.id),
                          );
                        }).toList(),
                      ),
                      if (!hasAssignee)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Falta asignar este ítem a alguien.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: vm.allItemsAssigned
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El cálculo del reparto y el resumen final todavía no están disponibles. Estarán listos pronto.',
                        ),
                      ),
                    );
                  }
                : null,
            child: Text(
              vm.allItemsAssigned
                  ? 'Continuar'
                  : 'Faltan ${vm.unassignedItemIndexes.length} ítem(s) por asignar',
            ),
          ),
        ),
      ],
    );
  }
}
