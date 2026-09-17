import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import 'people_groups_screen.dart' show initialsFrom;

/// Administra los miembros de un grupo guardado: quitar alguien del grupo,
/// o agregar personas ya existentes (o una nueva) a él.
class GroupEditScreen extends StatelessWidget {
  final int groupId;
  final String groupName;

  const GroupEditScreen({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Scaffold(
      appBar: AppBar(title: Text(groupName)),
      body: StreamBuilder<List<PeopleData>>(
        stream: db.groupsDao.watchMembers(groupId),
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <PeopleData>[];
          if (members.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este grupo todavía no tiene personas.\n'
                  'Agrega alguna con el botón de abajo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final person = members[index];
              return ListTile(
                leading: CircleAvatar(child: Text(person.avatarInitials)),
                title: Text(person.name),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => db.groupsDao.removeMember(groupId, person.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberSheet(context, db),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Agregar persona'),
      ),
    );
  }

  Future<void> _showAddMemberSheet(BuildContext context, AppDatabase db) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddMemberSheet(groupId: groupId, db: db),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final int groupId;
  final AppDatabase db;
  const _AddMemberSheet({required this.groupId, required this.db});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _newPersonController = TextEditingController();

  @override
  void dispose() {
    _newPersonController.dispose();
    super.dispose();
  }

  Future<void> _createAndAddPerson() async {
    final name = _newPersonController.text.trim();
    if (name.isEmpty) return;
    final id = await widget.db.peopleDao.upsertPerson(
      PeopleCompanion.insert(name: name, avatarInitials: initialsFrom(name)),
    );
    await widget.db.groupsDao.addMember(widget.groupId, id);
    _newPersonController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agregar persona al grupo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPersonController,
                      decoration: const InputDecoration(hintText: 'Nombre de una persona nueva'),
                      onSubmitted: (_) => _createAndAddPerson(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _createAndAddPerson, child: const Text('Agregar')),
                ],
              ),
              const Divider(height: 32),
              Text('O elige de tus personas guardadas', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: StreamBuilder<List<PeopleData>>(
                  stream: widget.db.peopleDao.watchAllPeople(),
                  builder: (context, allSnapshot) {
                    return StreamBuilder<List<PeopleData>>(
                      stream: widget.db.groupsDao.watchMembers(widget.groupId),
                      builder: (context, memberSnapshot) {
                        final all = allSnapshot.data ?? const <PeopleData>[];
                        final memberIds = (memberSnapshot.data ?? const <PeopleData>[]).map((p) => p.id).toSet();
                        final available = all.where((p) => !memberIds.contains(p.id)).toList();
                        if (available.isEmpty) {
                          return const Center(child: Text('Todas tus personas guardadas ya están en este grupo.'));
                        }
                        return ListView.builder(
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final person = available[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text(person.avatarInitials)),
                              title: Text(person.name),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () => widget.db.groupsDao.addMember(widget.groupId, person.id),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
