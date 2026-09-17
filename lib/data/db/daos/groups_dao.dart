import 'package:drift/drift.dart';

import '../app_database.dart';

part 'groups_dao.g.dart';

@DriftAccessor(tables: [Groups, GroupMembers, People])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(super.db);

  Stream<List<Group>> watchAllGroups() {
    return (select(groups)..orderBy([(g) => OrderingTerm.asc(g.name)])).watch();
  }

  Future<int> createGroup(String name) => into(groups).insert(GroupsCompanion.insert(name: name));

  Future<void> deleteGroup(int id) => (delete(groups)..where((g) => g.id.equals(id))).go();

  Stream<List<PeopleData>> watchMembers(int groupId) {
    final query = select(people).join([
      innerJoin(groupMembers, groupMembers.personId.equalsExp(people.id)),
    ])
      ..where(groupMembers.groupId.equals(groupId));
    return query.watch().map((rows) => rows.map((r) => r.readTable(people)).toList());
  }

  Future<void> addMember(int groupId, int personId) {
    return into(groupMembers).insertOnConflictUpdate(
      GroupMembersCompanion.insert(groupId: groupId, personId: personId),
    );
  }

  Future<void> removeMember(int groupId, int personId) {
    return (delete(groupMembers)
          ..where((gm) => gm.groupId.equals(groupId) & gm.personId.equals(personId)))
        .go();
  }
}
