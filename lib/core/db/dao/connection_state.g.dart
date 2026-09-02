// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_state.dart';

// ignore_for_file: type=lint
mixin _$ConnectionStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConnectionStateTable get connectionState => attachedDatabase.connectionState;
  ConnectionStateDaoManager get managers => ConnectionStateDaoManager(this);
}

class ConnectionStateDaoManager {
  final _$ConnectionStateDaoMixin _db;
  ConnectionStateDaoManager(this._db);
  $$ConnectionStateTableTableManager get connectionState =>
      $$ConnectionStateTableTableManager(
        _db.attachedDatabase,
        _db.connectionState,
      );
}
