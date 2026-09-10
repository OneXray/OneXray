import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/advanced/platform_policy.dart';
import 'package:onexray/service/connect/platform_requirements.dart';
import 'package:onexray/service/connect/resolver.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/routing/custom/service.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:path/path.dart' as p;

Future<List<int>> allocateRuntimePorts(
  List<dynamic> rawInbounds, {
  Future<List<int>> Function(int count)? getFreePorts,
}) async {
  final allocate = getFreePorts ?? AppHostApi().getFreePorts;
  for (var attempt = 0; attempt < 5; attempt++) {
    final candidates = await allocate(2);
    if (candidates.length == 2 &&
        candidates.toSet().length == 2 &&
        candidates.every((port) => port > 0 && port <= 65535) &&
        !rawInbounds.any(
          (entry) =>
              entry is Map &&
              candidates.any(
                (port) => ConnectionCompiler.portIncludes(entry['port'], port),
              ),
        )) {
      return candidates;
    }
  }
  throw const FormatException('Runtime ports are unavailable');
}

/// Resolves and validates without publishing settings or starting a VPN.
class ConnectionPreparation {
  final AppDatabase db;
  final ConnectionResolver resolver;

  ConnectionPreparation({AppDatabase? db, ConnectionResolver? resolver})
    : db = db ?? AppDatabase(),
      resolver =
          resolver ??
          ConnectionResolver(
            rows: () {
              final database = db ?? AppDatabase();
              return (database.select(
                database.coreConfig,
              )..where((row) => row.type.equals('outbound'))).watch();
            },
          );

  Future<ConnectionRuntime> prepare(
    ConnectionConfiguration input, {
    Future<void>? cancelled,
    String? rawDraft,
    RoutingProfileState? customDraft,
    Map<int, ResolvedServer> serverDrafts = const {},
    void Function(Set<int>)? onResolved,
  }) async {
    var configuration = input;
    var settings = input.connection;
    final policy = input.policy;
    final platform = connectionPlatform;
    await ConnectionPlatformRequirements(platform: platform)
        .ensureOutboundInterface(policy.xrayOutboundInterfaceName);
    final tun = policy.toTun(platform);
    String? raw = rawDraft;
    RoutingProfileState? custom = customDraft;
    if (settings.expert && raw == null) {
      final row = settings.rawId == null
          ? null
          : await db.coreConfigDao.searchRow(settings.rawId!);
      if (row == null || row.type != 'raw') {
        throw const FormatException('Raw configuration is unavailable');
      }
      if (row.data == null) {
        throw const FormatException('Raw configuration is empty');
      }
      raw = utf8.decode(base64Decode(row.data!));
    } else if (!settings.expert &&
        settings.trafficMode == TrafficMode.custom &&
        custom == null) {
      final row = settings.customId == null
          ? null
          : await db.routingProfileDao.searchRow(settings.customId!);
      if (row == null) {
        throw const FormatException('Custom route is unavailable');
      }
      custom = CustomRoutingService.read(row);
    }
    String? notice;
    List<ResolvedServer> entries;
    try {
      entries = await resolver.resolve(
        settings,
        custom: custom,
        cancelled: cancelled,
      );
    } on ConnectionResolutionException catch (error) {
      if (settings.selection.kind == SelectionKind.automatic ||
          !{
            ConnectionResolutionFailure.selectionUnavailable,
            ConnectionResolutionFailure.insufficientHealthyServers,
          }.contains(error.reason)) {
        rethrow;
      }
      settings = ConnectionSettings.fromJson({
        ...settings.toJson(),
        'selection': const ServerSelection.automatic().toJson(),
      });
      entries = await resolver.resolve(
        settings,
        custom: custom,
        cancelled: cancelled,
      );
      configuration = ConnectionConfiguration(
        connection: settings,
        policy: policy,
      );
      notice = 'selectionReset';
    }
    entries = [for (final entry in entries) serverDrafts[entry.id] ?? entry];
    onResolved?.call({
      for (final entry in entries) entry.id,
      if (settings.finalExitId != null) settings.finalExitId!,
    });
    ResolvedServer? finalExit;
    if (settings.finalExitId != null) {
      final row = await db.coreConfigDao.searchRow(settings.finalExitId!);
      if (row == null) throw const FormatException('Final exit is unavailable');
      finalExit = serverDrafts[row.id] ?? ResolvedServer.fromRow(row);
    }
    var regions = const RegionCatalog.empty();
    if (!settings.expert &&
        settings.trafficMode == TrafficMode.smart &&
        settings.smart.directRegions.isNotEmpty) {
      Future<Map<String, dynamic>> readIndex(String name) async => jsonDecode(
        await File(p.join(VpnConstants.datDir, '$name.json')).readAsString(),
      ) as Map<String, dynamic>;
      regions = RegionCatalog.fromJson(
        jsonDecode(await rootBundle.loadString(RegionCatalog.assetPath))
            as Map<String, dynamic>,
        geositeCodes: RegionCatalog.codesFromIndex(await readIndex('geosite')),
        geoipCodes: RegionCatalog.codesFromIndex(await readIndex('geoip')),
      );
    }
    final rawConfig = raw == null ? null : ConnectionCompiler.parseRawJson(raw);
    final rawInbounds = rawConfig?['inbounds'] ?? [];
    if (rawInbounds is! List ||
        rawInbounds.any((entry) => entry is! Map<String, dynamic>)) {
      throw const FormatException('inbounds must be an object array');
    }
    final ports = await allocateRuntimePorts(
      rawInbounds.cast<Map<String, dynamic>>(),
    );
    final compiled = ConnectionCompiler.compile(
      settings: settings,
      entries: entries,
      finalExit: finalExit,
      raw: rawConfig,
      custom: custom,
      regions: regions,
      options: RuntimeOptions(
        platform: platform,
        sessionDirectory: VpnConstants.runDir,
        socksPort: ports[0],
        metricsPort: ports[1],
        ipv6: policy.ipv6Enabled,
        interfaceName: policy.xrayOutboundInterfaceName,
        logEnabled: policy.logEnabled,
        logLevel: policy.logLevel,
        dnsLog: policy.recordDns,
        maskAddress: policy.maskAddress,
      ),
    );
    final validation = await AppHostApi().testXray(compiled.validationJson);
    if (validation.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: validation,
      );
    }
    for (final server in [...entries, ?finalExit]) {
      final row = await db.coreConfigDao.searchRow(server.id);
      if (row == null ||
          row.type != 'outbound' ||
          (!serverDrafts.containsKey(row.id) &&
              ResolvedServer.fromRow(row).outboundJson !=
                  server.outboundJson)) {
        throw const FormatException(
          'A selected server changed during preparation',
        );
      }
    }
    final request = StartVpnRequest(
      tun,
      platform == ConnectionPlatform.windows ||
              platform == ConnectionPlatform.ios
          ? '${ports[0]}'
          : null,
      '${ports[1]}',
      jsonEncode(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(compiled.xrayJson).toJson(),
        ).toJson(),
      ),
    );
    return ConnectionRuntime.create(
      configuration: configuration,
      compiled: compiled,
      platform: platform,
      request: request,
      notice: notice,
    );
  }
}
