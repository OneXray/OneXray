// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routing_profile.dart';

// ignore_for_file: type=lint
mixin _$RoutingProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $RoutingProfileTable get routingProfile => attachedDatabase.routingProfile;
  RoutingProfileDaoManager get managers => RoutingProfileDaoManager(this);
}

class RoutingProfileDaoManager {
  final _$RoutingProfileDaoMixin _db;
  RoutingProfileDaoManager(this._db);
  $$RoutingProfileTableTableManager get routingProfile =>
      $$RoutingProfileTableTableManager(
        _db.attachedDatabase,
        _db.routingProfile,
      );
}
