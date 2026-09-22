import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:onexray/service/connect/routing/custom/state_db.dart';
import 'package:onexray/service/connect/routing/dns.dart';
import 'package:onexray/service/shared/xray/runtime_outbounds.dart';
import 'package:onexray/service/shared/xray/validation.dart';
import 'package:onexray/service/shared/xray/fake_dns.dart';
import 'package:onexray/service/connect/routing/custom/configuration.dart';
import 'package:onexray/service/connect/routing/custom/advanced.dart';

/// Persists validated Custom-routing state. Applying a currently used profile
/// remains the connection coordinator's responsibility.
class CustomRoutingService {
  final AppDatabase database;

  CustomRoutingService(this.database);

  static RoutingProfileState read(RoutingProfileData row) =>
      RoutingProfileStateDb.read(row);

  static RoutingConfiguration readConfiguration(RoutingProfileData row) =>
      RoutingProfileStateDb.readConfiguration(row);

  /// Empty entry slots are editor metadata, not runnable Xray outbounds.
  /// Use local placeholders for validation; never resolve or connect a server.
  static Future<void> validate(
    RoutingConfiguration state, {
    Future<String> Function(String)? testXray,
  }) => GeoDataService().withFiles(() async {
    final error = await (testXray ?? AppHostApi().testXray)(
      validationJson(state),
    );
    if (error.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: error,
      );
    }
  });

  /// Shared by the editor and local API; this does not select stored nodes.
  static String validationJson(RoutingConfiguration state) {
    if (state is AdvancedRoutingProfile) {
      final config = state.fillSlots([
        for (var i = 0; i < state.entryCount; i++)
          createFreedomOutbound(tag: 'app-entry-$i').toJson(),
      ]);
      return XrayValidation.raw(config);
    }
    state as RoutingProfileState;
    final config = state.xrayJson;
    config.dns = RoutingDns.compile(
      directAddress: state.directDnsAddress.trim(),
      fakeDns: state.fakeDns,
      directDomains: RoutingDns.directDomains(
        config.routing?.rules ?? const [],
      ),
    );
    config.fakedns = FakeDns.poolsFor(config.dns);
    final tags = [for (var i = 0; i < state.entryCount; i++) 'app-entry-$i'];
    config.outbounds = [
      for (final tag in tags) createFreedomOutbound(tag: tag).toJson(),
      createFreedomOutbound(tag: 'direct').toJson(),
      createBlackholeOutbound(tag: 'block').toJson(),
    ];
    (config.routing ??= XrayRouting()).balancers = [
      XrayBalancer(
        tag: 'proxy',
        selector: tags,
        strategy: XrayBalancingStrategy(type: 'roundRobin'),
        fallbackTag: 'direct',
      ),
    ];
    // fallbackTag requires the same Observatory dependency as runtime routing.
    config.observatory = XrayObservatory(subjectSelector: []);
    return XrayValidation.normal(config);
  }

  Future<int> save(RoutingConfiguration state) async {
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
      if (previous.advanced != value.advanced) {
        throw const FormatException('Custom routing mode cannot be changed');
      }
      await database.routingProfileDao.updateRow(value.updateData(previous));
      return value.id!;
    });
  }
}
