import 'package:collection/collection.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';
import 'package:onexray/service/routing/region_catalog.dart';

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

  SmartRoutingEditorService({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    this.loadRegions,
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
        'resolveIpOnNoMatch': value.resolveIpOnNoMatch,
        'dnsDomains': value.directDns
            ? [
                for (final rule in rules)
                  if (rule.outboundTag == 'direct') ...?rule.domain,
              ]
            : <String>[],
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
