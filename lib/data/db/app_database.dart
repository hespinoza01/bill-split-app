import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/bills_dao.dart';
import 'daos/groups_dao.dart';
import 'daos/people_dao.dart';

part 'app_database.g.dart';

class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get avatarInitials => text().withLength(min: 1, max: 3)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class GroupMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {groupId, personId},
      ];
}

enum BillStatus { draft, finalized }

class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get restaurantName => text().nullable()();
  TextColumn get rawOcrText => text().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  RealColumn get tipAmount => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get status => textEnum<BillStatus>().withDefault(Constant(BillStatus.draft.name))();
  TextColumn get photoPath => text().nullable()();
}

class LineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get unitPrice => real()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  RealColumn get lineTotal => real()();
}

// Snapshot of who participates in a specific bill, decoupled from Group
// membership so editing a Group later doesn't retroactively change history.
class BillPeople extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get billId => integer().references(Bills, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {billId, personId},
      ];
}

// One row per (lineItem, billPerson) pair the item is shared with; the
// calculator divides lineTotal evenly across all Assignment rows for that item.
class Assignments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lineItemId => integer().references(LineItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get billPersonId => integer().references(BillPeople, #id, onDelete: KeyAction.cascade)();
  RealColumn get shareWeight => real().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {lineItemId, billPersonId},
      ];
}

@DriftDatabase(
  tables: [People, Groups, GroupMembers, Bills, LineItems, BillPeople, Assignments],
  daos: [BillsDao, PeopleDao, GroupsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'bill_split_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
