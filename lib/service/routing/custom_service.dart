import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:onexray/service/routing/state_db.dart';
import 'package:onexray/service/xray/runtime_outbounds.dart';

/// Persists validated Custom-routing state. Applying a currently used profile
/// remains the connection coordinator's responsibility.
class CustomRoutingService {
  final AppDatabase database;

  CustomRoutingService(this.database);

  static RoutingProfileState read(RoutingProfileData row) =>
      RoutingProfileStateDb.read(row);

  /// Empty entry slots are editor metadata, not runnable Xray outbounds.
  /// Use local placeholders for validation; never resolve or connect a server.
  static Future<void> validate(
    RoutingProfileState state, {
    Future<String> Function(String)? testXray,
  }) async {
    final config = state.xrayJson;
    final tags = [for (var i = 0; i < state.entryCount; i++) 'app-entry-$i'];
    config.env = XrayEnv(
      assetLocation: VpnConstants.datDir,
      certLocation: VpnConstants.datDir,
    );
    config.outbounds = [
      for (final tag in tags) createFreedomOutbound(tag: tag).toJson(),
      createFreedomOutbound(tag: 'direct').toJson(),
      createBlackholeOutbound(tag: 'block').toJson(),
    ];
    (config.routing ??= XrayRouting()).balancers = [
      XrayBalancer(tag: 'proxy', selector: tags, fallbackTag: 'direct'),
    ];
    final error = await (testXray ?? AppHostApi().testXray)(
      JsonTool.encoder.convert(config.toJson()),
    );
    if (error.isNotEmpty) throw FormatException(error);
  }

  Future<int> save(RoutingProfileState state) => DataMaintenance.run(() async {
    final name = state.name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const FormatException(
        'Custom route name must contain 1–32 characters',
      );
    }
    final value = state.copyWith(name: name);
    value.validate();
    return database.transaction(() async {
      if ((await database.routingProfileDao.allRows).any(
        (row) =>
            row.id != value.id &&
            row.name.trim().toLowerCase() == name.toLowerCase(),
      )) {
        throw const FormatException('Custom route names must be unique');
      }
      if (value.id == null) {
        return database.routingProfileDao.insertRow(value.insertCompanion);
      }
      final previous = await database.routingProfileDao.searchRow(value.id!);
      if (previous == null) throw StateError('Custom route no longer exists');
      await database.routingProfileDao.updateRow(value.updateData(previous));
      return value.id!;
    });
  });
}
