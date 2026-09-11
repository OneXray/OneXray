import 'package:collection/collection.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/routing/custom/geodata_suggestions.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:onexray/service/connect/routing/dns.dart';
import 'package:onexray/service/shared/xray/runtime_outbounds.dart';
import 'package:onexray/service/shared/xray/validation.dart';

class SmartRoutingEditorDraft {
  final ConnectionConfiguration configuration;
  final RegionCatalog regions;
  final String? selectionName;
  final String? finalExitName;
  const SmartRoutingEditorDraft({
    required this.configuration,
    required this.regions,
    this.selectionName,
    this.finalExitName,
  });
}

/// Editing Smart settings never selects Smart or resolves entry servers.
class SmartRoutingEditorService {
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final Future<RegionCatalog> Function()? loadRegions;
  final Future<String> Function(String)? testXray;

  SmartRoutingEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    this.loadRegions,
    this.testXray,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance;

  Future<RegionCatalog> regions() async => loadRegions != null
      ? loadRegions!()
      : (await RoutingGeodataIndex.load(database: db)).regionCatalog();

  Future<SmartRoutingEditorDraft> load() async {
    await coordinator.initialize();
    final configuration = await coordinator.configuration;
    final selection = configuration.connection.selection;
    return SmartRoutingEditorDraft(
      configuration: configuration,
      regions: await regions(),
      selectionName: switch (selection.kind) {
        SelectionKind.server => await serverName(selection.id),
        SelectionKind.source => (await db.subscriptionDao.searchRow(
          selection.id!,
        ))?.name,
        _ => null,
      },
      finalExitName: await serverName(
        configuration.connection.smart.finalExitId,
      ),
    );
  }

  Future<String?> serverName(int? id) async {
    if (id == null) return null;
    final row = await db.coreConfigDao.searchRow(id);
    if (row == null || row.type != 'outbound') return null;
    return ResolvedServer.fromRow(row).name;
  }

  Future<bool> save({
    required ConnectionConfiguration original,
    required SmartRoutingSettings smart,
    required Future<bool> Function() confirmReconnect,
  }) async {
    smart = SmartRoutingSettings.fromJson({
      ...smart.toJson(),
      'directDnsAddress': smart.directDnsAddress.trim(),
    });
    await coordinator.initialize();
    await coordinator.refresh();
    if ((await coordinator.configuration).encode() != original.encode()) {
      throw const ConnectionHostException('configurationChanged');
    }
    final connection = original.connection;
    final affectsRuntime =
        !connection.expert &&
        connection.trafficMode == TrafficMode.smart &&
        !sameRuntime(connection, smart, await regions());
    var allowReconnect = false;
    if (affectsRuntime &&
        coordinator.state.value.phase == ConnectionPhase.connected) {
      allowReconnect = await confirmReconnect();
      if (!allowReconnect) return false;
    }
    final next = ConnectionConfiguration(
      connection: ConnectionSettings.fromJson({
        ...connection.toJson(),
        'smart': smart.toJson(),
      }),
      policy: original.policy,
    );
    await coordinator.apply(
      next,
      affectsRuntime: affectsRuntime,
      allowReconnect: allowReconnect,
      expectedConfiguration: original.encode(),
      validateAssets:
          smart.directDns &&
              (!connection.smart.directDns ||
                  smart.directDnsAddress != connection.smart.directDnsAddress)
          ? () => _validateDns(smart.directDnsAddress)
          : null,
      writeAssets: () async {
        if (smart.finalExitId == null) return;
        if ((connection.selection.kind == SelectionKind.server &&
                connection.selection.id == smart.finalExitId) ||
            await serverName(smart.finalExitId) == null) {
          throw const FormatException('Invalid final exit selection');
        }
      },
    );
    return true;
  }

  Future<void> _validateDns(String address) async {
    final error = await (testXray ?? AppHostApi().testXray)(
      XrayValidation.normal(
        XrayJson(
          dns: RoutingDns.compile(directAddress: address),
          outbounds: [createFreedomOutbound(tag: 'direct').toJson()],
        ),
      ),
    );
    if (error.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: error,
      );
    }
  }

  static bool sameRuntime(
    ConnectionSettings original,
    SmartRoutingSettings next,
    RegionCatalog regions,
  ) {
    Object semantic(SmartRoutingSettings value) {
      final rules = ConnectionCompiler.smartRules(value, regions);
      // Region order does not change a rule's OR set or the direct DNS set.
      for (final rule in rules) {
        rule.domain?.sort();
        rule.ip?.sort();
      }
      return {
        'rules': [for (final rule in rules) rule.toJson()],
        'dnsDomains': value.directDns
            ? [
                for (final rule in rules)
                  if (rule.outboundTag == 'direct') ...?rule.domain,
              ]
            : <String>[],
        'directDnsAddress': value.effectiveDirectDnsAddress,
        'entryCount': original.selection.kind == SelectionKind.server
            ? 1
            : value.entryCount,
        'finalExitId': value.finalExitId,
      };
    }

    return const DeepCollectionEquality().equals(
      semantic(original.smart),
      semantic(next),
    );
  }
}
