// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// ignore_for_file: type=lint
mixin _$SubscriptionDaoMixin on DatabaseAccessor<AppDatabase> {
  $SubscriptionTable get subscription => attachedDatabase.subscription;
  $CoreConfigTable get coreConfig => attachedDatabase.coreConfig;
  SubscriptionDaoManager get managers => SubscriptionDaoManager(this);
}

class SubscriptionDaoManager {
  final _$SubscriptionDaoMixin _db;
  SubscriptionDaoManager(this._db);
  $$SubscriptionTableTableManager get subscription =>
      $$SubscriptionTableTableManager(_db.attachedDatabase, _db.subscription);
  $$CoreConfigTableTableManager get coreConfig =>
      $$CoreConfigTableTableManager(_db.attachedDatabase, _db.coreConfig);
}
