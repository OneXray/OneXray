// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_routing_profiles.dart';

// ignore_for_file: type=lint
mixin _$CustomRoutingProfilesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomRoutingProfilesTable get customRoutingProfiles =>
      attachedDatabase.customRoutingProfiles;
  CustomRoutingProfilesDaoManager get managers =>
      CustomRoutingProfilesDaoManager(this);
}

class CustomRoutingProfilesDaoManager {
  final _$CustomRoutingProfilesDaoMixin _db;
  CustomRoutingProfilesDaoManager(this._db);
  $$CustomRoutingProfilesTableTableManager get customRoutingProfiles =>
      $$CustomRoutingProfilesTableTableManager(
        _db.attachedDatabase,
        _db.customRoutingProfiles,
      );
}
