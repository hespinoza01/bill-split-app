import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../people_groups/people_groups_screen.dart' show initialsFrom;
import 'assignment_screen.dart';
import 'reviewed_bill_data.dart';

/// Paso previo a Assignment: elegir quién participa en esta factura —
/// reutilizando un grupo guardado, seleccionando personas sueltas, o
/// agregando alguien nuevo sobre la marcha. La selección de esta pantalla
/// es solo pa ESTA factura (no altera grupos guardados).
class PeopleSelectionScreen extends StatefulWidget {
  final ReviewedBillData bill;

  const PeopleSelectionScreen({super.key, required this.bill});

  @override
  State<PeopleSelectionScreen> createState() => _PeopleSelectionScreenState();
}

class _PeopleSelectionScreenState extends State<PeopleSelectionScreen> {
  final _selectedIds = <int>{};
  final _newPersonController = TextEditingController();

  @override
  void dispose() {
    _newPersonController.dispose();
    super.dispose();
  }

  Future<void> _selectGroup(AppDatabase db, int groupId) async {
    final members = await db.groupsDao.watchMembers(groupId).first;
    setState(() => _selectedIds.addAll(members.map((m) => m.id)));
  }

  Future<void> _addNewPerson(AppDatabase db) async {
    final name = _newPersonController.text.trim();
    if (name.isEmpty) return;
    final id = await db.peopleDao.upsertPerson(
      PeopleCompanion.insert(name: name, avatarInitials: initialsFrom(name)),
    );
    setState(() {
      _selectedIds.add(id);
      _newPersonController.clear();
    });
  }

  void _toggle(int personId) {
    setState(() {
      if (_selectedIds.contains(personId)) {
        _selectedIds.remove(personId);
      } else {
        _selectedIds.add(personId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('¿Quiénes van a compartir esta cuenta?')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<List<Group>>(
              stream: db.groupsDao.watchAllGroups(),
              builder: (context, snapshot) {
                final groups = snapshot.data ?? const <Group>[];
                if (groups.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grupos guardados', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: groups.map((g) {
                        return ActionChip(
                          avatar: const Icon(Icons.group, size: 18),
                          label: Text(g.name),
                          onPressed: () => _selectGroup(db, g.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPersonController,
                    decoration: const InputDecoration(
                      labelText: 'Agregar persona nueva',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addNewPerson(db),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _addNewPerson(db), child: const Text('Agregar')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Todas tus personas guardadas', style: Theme.of(context).textTheme.titleSmall),
            Expanded(
              child: StreamBuilder<List<PeopleData>>(
                stream: db.peopleDao.watchAllPeople(),
                builder: (context, snapshot) {
                  final people = snapshot.data ?? const <PeopleData>[];
                  if (people.isEmpty) {
                    return const Center(child: Text('Todavía no tienes personas guardadas. Agrega una arriba.'));
                  }
                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final selected = _selectedIds.contains(person.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(person.id),
                        secondary: CircleAvatar(child: Text(person.avatarInitials)),
                        title: Text(person.name),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssignmentScreen(bill: widget.bill, personIds: _selectedIds.toList()),
                        ),
                      );
                    },
              child: Text(_selectedIds.isEmpty ? 'Selecciona al menos una persona' : 'Continuar (${_selectedIds.length} personas)'),
            ),
          ],
        ),
      ),
    );
  }
}
