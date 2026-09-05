// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_config.dart';

// ignore_for_file: type=lint
mixin _$ConnectionConfigDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConnectionConfigTable get connectionConfig =>
      attachedDatabase.connectionConfig;
  ConnectionConfigDaoManager get managers => ConnectionConfigDaoManager(this);
}

class ConnectionConfigDaoManager {
  final _$ConnectionConfigDaoMixin _db;
  ConnectionConfigDaoManager(this._db);
  $$ConnectionConfigTableTableManager get connectionConfig =>
      $$ConnectionConfigTableTableManager(
        _db.attachedDatabase,
        _db.connectionConfig,
      );
}
