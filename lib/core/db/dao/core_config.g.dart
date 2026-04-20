// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_config.dart';

// ignore_for_file: type=lint
mixin _$CoreConfigDaoMixin on DatabaseAccessor<AppDatabase> {
  $CoreConfigTable get coreConfig => attachedDatabase.coreConfig;
  $SubscriptionTable get subscription => attachedDatabase.subscription;
  CoreConfigDaoManager get managers => CoreConfigDaoManager(this);
}

class CoreConfigDaoManager {
  final _$CoreConfigDaoMixin _db;
  CoreConfigDaoManager(this._db);
  $$CoreConfigTableTableManager get coreConfig =>
      $$CoreConfigTableTableManager(_db.attachedDatabase, _db.coreConfig);
  $$SubscriptionTableTableManager get subscription =>
      $$SubscriptionTableTableManager(_db.attachedDatabase, _db.subscription);
}
