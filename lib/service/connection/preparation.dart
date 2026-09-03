import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/resolver.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/custom_template.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:path/path.dart' as p;

ConnectionPlatform get connectionPlatform => switch (Platform.operatingSystem) {
  'ios' => ConnectionPlatform.ios,
  'macos' => ConnectionPlatform.macos,
  'android' => ConnectionPlatform.android,
  'windows' => ConnectionPlatform.windows,
  'linux' => ConnectionPlatform.linux,
  _ => throw UnsupportedError('Unsupported platform'),
};

String newPlanId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
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

  Future<ConnectionPlan> prepare(
    ConnectionConfiguration input, {
    Future<void>? cancelled,
    String? rawDraft,
    CustomRoutingTemplate? customDraft,
    Map<int, ServerSnapshot> serverDrafts = const {},
    void Function(Set<int>)? onResolved,
    Future<void> Function(String datDirectory)? prepareAssets,
  }) async {
    var configuration = input;
    var settings = input.connection;
    final policy = input.policy;
    final platform = connectionPlatform;
    final tun = policy.toTun(platform);
    String? raw = rawDraft;
    CustomRoutingTemplate? custom = customDraft;
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
      custom = CustomRoutingTemplate.parse(utf8.decode(base64Decode(row.data)));
    }
    String? notice;
    List<ServerSnapshot> entries;
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
    ServerSnapshot? finalExit;
    if (settings.finalExitId != null) {
      final row = await db.coreConfigDao.searchRow(settings.finalExitId!);
      if (row == null) throw const FormatException('Final exit is unavailable');
      finalExit = serverDrafts[row.id] ?? ServerSnapshot.fromRow(row);
    }
    final id = newPlanId();
    final directory = Directory(p.join(VpnConstants.runDir, 'plans', id));
    await directory.create(recursive: true);
    try {
      // Freeze one published row snapshot. Default files always share a generation.
      final assets = Directory(p.join(directory.path, 'dat'));
      await assets.create();
      await GeoDataService().copyPublishedTo(assets.path);
      for (final name in ['geosite', 'geoip']) {
        if (!await File(p.join(assets.path, '$name.dat')).exists()) {
          throw const FormatException('Default routing data is missing');
        }
      }
      await prepareAssets?.call(assets.path);
      Future<Map<String, dynamic>> readIndex(String name) async => jsonDecode(
        await File(p.join(assets.path, '$name.json')).readAsString(),
      ) as Map<String, dynamic>;
      final regions = RegionCatalog.fromJson(
        jsonDecode(await rootBundle.loadString(RegionCatalog.assetPath))
            as Map<String, dynamic>,
        geositeCodes: RegionCatalog.codesFromIndex(await readIndex('geosite')),
        geoipCodes: RegionCatalog.codesFromIndex(await readIndex('geoip')),
      );
      final rawObject = raw == null
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
      final rawInbounds = rawObject?['inbounds'] as List<dynamic>? ?? [];
      List<int>? ports;
      for (var attempt = 0; attempt < 5; attempt++) {
        final candidates = await AppHostApi().getFreePorts(3);
        if (candidates.length == 3 &&
            candidates.toSet().length == 3 &&
            !rawInbounds.any(
              (entry) =>
                  entry is Map &&
                  candidates.any(
                    (port) =>
                        ConnectionCompiler.portIncludes(entry['port'], port),
                  ),
            )) {
          ports = candidates;
          break;
        }
      }
      if (ports == null) {
        throw const FormatException('Runtime ports are unavailable');
      }
      final bootstrap = <String, List<String>>{};
      if (!policy.ipv6Enabled) {
        final outbounds = rawObject == null
            ? [
                ...entries.map((entry) => entry.outbound),
                if (finalExit != null) finalExit.outbound,
              ]
            : (rawObject['outbounds'] as List).cast<Map<String, dynamic>>();
        for (final address in outbounds.expand(outboundAddresses).toSet()) {
          if (InternetAddress.tryParse(address) != null) continue;
          final addresses = await InternetAddress.lookup(
            address,
            type: InternetAddressType.IPv4,
          ).timeout(const Duration(seconds: 10));
          if (addresses.isEmpty) {
            throw const FormatException('No IPv4 bootstrap address');
          }
          bootstrap[address] = addresses
              .map((ip) => ip.address)
              .toSet()
              .toList();
        }
      }
      final auth = XrayInboundAccountFactory.random();
      final compiled = ConnectionCompiler.compile(
        settings: settings,
        entries: entries,
        finalExit: finalExit,
        rawText: raw,
        custom: custom,
        regions: regions,
        options: RuntimeOptions(
          platform: platform,
          assetDirectory: assets.path,
          sessionDirectory: directory.path,
          socksPort: ports[0],
          pingPort: ports[1],
          metricsPort: ports[2],
          pingAuth: auth,
          ipv6: policy.ipv6Enabled,
          interfaceName: policy.xrayOutboundInterfaceName,
          logEnabled: policy.logEnabled,
          logLevel: policy.logLevel,
          dnsLog: policy.recordDns,
          maskAddress: policy.maskAddress,
          bootstrapAddresses: bootstrap,
        ),
      );
      final validation = await AppHostApi().testXray(
        compiled.xrayJson,
        buildOnly: true,
      );
      if (validation.isNotEmpty) {
        throw const FormatException('Xray configuration validation failed');
      }
      for (final snapshot in [...entries, ?finalExit]) {
        final row = await db.coreConfigDao.searchRow(snapshot.id);
        if (row == null ||
            row.type != 'outbound' ||
            (!serverDrafts.containsKey(row.id) &&
                ServerSnapshot.fromRow(row).outboundJson !=
                    snapshot.outboundJson)) {
          throw const FormatException(
            'A selected server changed during preparation',
          );
        }
      }
      final runtime = ManagedRuntimeRequest(
        statePath: p.join(VpnConstants.runDir, 'runtime.json'),
        planId: id,
      );
      final request = StartVpnRequest(
        tun,
        platform == ConnectionPlatform.windows ||
                platform == ConnectionPlatform.ios
            ? '${ports[0]}'
            : null,
        '${ports[1]}',
        auth,
        '${ports[2]}',
        jsonEncode(
          LibXrayInvokeRequest(
            method: LibXrayMethod.runXray,
            payload: RunXrayRequest(
              compiled.xrayJson,
              runtime: runtime,
            ).toJson(),
          ).toJson(),
        ),
      );
      final plan = ConnectionPlan.create(
        id: id,
        configuration: configuration,
        compiled: compiled,
        platform: platform,
        request: request,
        notice: notice,
      );
      await File(p.join(directory.path, 'plan.json'))
          .writeAsString(plan.encode(), flush: true);
      await File(p.join(directory.path, 'xray.json'))
          .writeAsString(compiled.xrayJson, flush: true);
      return plan;
    } catch (_) {
      // This plan has not been returned or published. Remove only its own
      // generated directory on preparation/validation failure.
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }
}
