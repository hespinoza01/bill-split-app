import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import 'group_edit_screen.dart';

/// CRUD de personas y grupos guardados — reusables entre facturas (ej.
/// "amigos del viernes") para no reescribir nombres cada vez.
class PeopleGroupsScreen extends StatelessWidget {
  const PeopleGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personas y grupos'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Grupos'), Tab(text: 'Personas')],
          ),
        ),
        body: const TabBarView(
          children: [_GroupsTab(), _PeopleTab()],
        ),
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Scaffold(
      body: StreamBuilder<List<Group>>(
        stream: db.groupsDao.watchAllGroups(),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <Group>[];
          if (groups.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes grupos guardados.\n'
                  'Crea uno con el botón de abajo pa reutilizarlo en futuras facturas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const Icon(Icons.group),
                title: Text(group.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeleteGroup(context, db, group),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GroupEditScreen(groupId: group.id, groupName: group.name)),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context, AppDatabase db) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Por ejemplo: Amigos del viernes'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await db.groupsDao.createGroup(name);
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, AppDatabase db, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text('¿Seguro que quieres eliminar el grupo "${group.name}"? Las personas no se eliminan, solo el grupo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await db.groupsDao.deleteGroup(group.id);
    }
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return Scaffold(
      body: StreamBuilder<List<PeopleData>>(
        stream: db.peopleDao.watchAllPeople(),
        builder: (context, snapshot) {
          final people = snapshot.data ?? const <PeopleData>[];
          if (people.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes personas guardadas.\n'
                  'Agrega una con el botón de abajo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return ListTile(
                leading: CircleAvatar(child: Text(person.avatarInitials)),
                title: Text(person.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeletePerson(context, db, person),
                ),
                onTap: () => _showEditPersonDialog(context, db, person),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditPersonDialog(context, db, null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva persona'),
      ),
    );
  }

  Future<void> _showEditPersonDialog(BuildContext context, AppDatabase db, PeopleData? existing) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nueva persona' : 'Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la persona'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await db.peopleDao.upsertPerson(
        PeopleCompanion(
          id: existing != null ? Value(existing.id) : const Value.absent(),
          name: Value(name),
          avatarInitials: Value(initialsFrom(name)),
        ),
      );
    }
  }

  Future<void> _confirmDeletePerson(BuildContext context, AppDatabase db, PeopleData person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar persona'),
        content: Text('¿Seguro que quieres eliminar a "${person.name}"? Esto la quita de todos los grupos donde esté.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true) {
      await db.peopleDao.deletePerson(person.id);
    }
  }
}

/// Genera iniciales (máx 2 letras) a partir de un nombre completo, para el
/// avatar de la persona — no se le pide al usuario que las escriba a mano.
String initialsFrom(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
