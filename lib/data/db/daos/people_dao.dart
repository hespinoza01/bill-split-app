import 'package:drift/drift.dart';

import '../app_database.dart';

part 'people_dao.g.dart';

@DriftAccessor(tables: [People])
class PeopleDao extends DatabaseAccessor<AppDatabase> with _$PeopleDaoMixin {
  PeopleDao(super.db);

  Stream<List<PeopleData>> watchAllPeople() {
    return (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  }

  Future<PeopleData> getPerson(int id) =>
      (select(people)..where((p) => p.id.equals(id))).getSingle();

  Future<int> upsertPerson(PeopleCompanion entry) {
    return into(people).insertOnConflictUpdate(entry);
  }

  Future<void> deletePerson(int id) => (delete(people)..where((p) => p.id.equals(id))).go();
}
