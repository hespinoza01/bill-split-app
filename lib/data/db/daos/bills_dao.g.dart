// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bills_dao.dart';

// ignore_for_file: type=lint
mixin _$BillsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BillsTable get bills => attachedDatabase.bills;
  $LineItemsTable get lineItems => attachedDatabase.lineItems;
  $PeopleTable get people => attachedDatabase.people;
  $BillPeopleTable get billPeople => attachedDatabase.billPeople;
  $AssignmentsTable get assignments => attachedDatabase.assignments;
  BillsDaoManager get managers => BillsDaoManager(this);
}

class BillsDaoManager {
  final _$BillsDaoMixin _db;
  BillsDaoManager(this._db);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db.attachedDatabase, _db.bills);
  $$LineItemsTableTableManager get lineItems =>
      $$LineItemsTableTableManager(_db.attachedDatabase, _db.lineItems);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db.attachedDatabase, _db.people);
  $$BillPeopleTableTableManager get billPeople =>
      $$BillPeopleTableTableManager(_db.attachedDatabase, _db.billPeople);
  $$AssignmentsTableTableManager get assignments =>
      $$AssignmentsTableTableManager(_db.attachedDatabase, _db.assignments);
}
