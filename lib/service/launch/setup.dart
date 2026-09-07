import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/advanced/platform_policy.dart';
import 'package:onexray/service/connect/platform_requirements.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/launch/storage_preparation.dart';
import 'package:onexray/service/connect/routing/custom/geodata_suggestions.dart';
import 'package:onexray/service/advanced/tunnel/interface.dart';

enum SetupStep { welcome, system, region, servers, complete }

class SetupFailure implements Exception {
  final String component;
  final PlatformPermissionResult? permission;
  const SetupFailure(this.component, {this.permission});
}

/// Setup prepares existing infrastructure. It never compiles a connection,
/// waits for probes, or invokes a platform VPN start command.
class SetupService {
  final AppDatabase? _database;
  final Future<void> Function()? _prepareLocal;
  final Future<PlatformPermissionResult> Function(bool request)? _permission;
  final Future<void> Function(ConnectionConfiguration)? _saveConfiguration;
  final Future<List<String>> Function()? _readRegionCodes;
  final PreferencesKey _preferences = PreferencesKey();
  final ConnectionPlatform platform;
  final bool _debugMode;

  SetupService({
    this._database,
    this._prepareLocal,
    this._permission,
    this._saveConfiguration,
    this._readRegionCodes,
    this._debugMode = kDebugMode,
    ConnectionPlatform? platform,
  }) : platform = platform ?? connectionPlatform;

  AppDatabase get _db => _database ?? AppDatabase();
  bool get requiresInterface =>
      platform == ConnectionPlatform.windows ||
      platform == ConnectionPlatform.linux;

  Future<SetupStep> currentStep() async {
    if (!await _preferences.readPrivacyAccepted()) return SetupStep.welcome;
    if (!await _preferences.readFirstRun()) return SetupStep.complete;
    return switch (await _preferences.readSetupStep()) {
      'region' => SetupStep.region,
      'servers' => SetupStep.servers,
      _ => SetupStep.system,
    };
  }

  Future<void> acceptPrivacy() async {
    await _preferences.savePrivacyAccepted(true);
    // A crash between these writes still resumes at System, never at Home.
    await _preferences.saveSetupStep(SetupStep.system.name);
  }

  Future<void> prepareLocal() async {
    if (!await _preferences.readPrivacyAccepted()) {
      throw const SetupFailure('privacy');
    }
    final prepare = _prepareLocal;
    if (prepare != null) return prepare();
    final databaseWasMissing = await StoragePreparation.ensureReady();
    await GeoDataService().ensureInstalled(
      resetOrphanedFiles: databaseWasMissing,
    );
    await regionCodes();
  }

  Future<ConnectionConfiguration> configuration() async =>
      ConnectionConfiguration.fromJson(
        jsonDecode((await _db.connectionConfigDao.read()).configurationJson)
            as Map<String, dynamic>,
      );

  Future<void> _save(ConnectionConfiguration value) async {
    final save = _saveConfiguration;
    if (save != null) return save(value);
    await _db.connectionConfigDao.commit(configurationJson: value.encode());
  }

  Future<PlatformPermissionResult> checkPermission({
    bool request = false,
  }) async {
    if (_debugMode && platform == ConnectionPlatform.ios) {
      return PlatformPermissionResult(
        kind: PlatformPermissionKind.appleVpn,
        state: PlatformPermissionState.notRequired,
      );
    }
    final permission = _permission;
    if (permission != null) return permission(request);
    return ConnectionPlatformRequirements(platform: platform)
        .check(request: request);
  }

  static bool permissionReady(PlatformPermissionResult value) =>
      ConnectionPlatformRequirements.permissionReady(value);

  Future<void> continueSystem(String interfaceName) async {
    await prepareLocal();
    final permission = await checkPermission();
    if (!permissionReady(permission)) {
      throw SetupFailure('permission', permission: permission);
    }
    if (requiresInterface &&
        !(await interfaces()).any((item) => item.name == interfaceName)) {
      throw const SetupFailure('interface');
    }
    final previous = await configuration();
    final policy = previous.policy.toJson();
    if (requiresInterface) policy['xrayOutboundInterfaceName'] = interfaceName;
    await _save(
      ConnectionConfiguration(
        connection: previous.connection,
        policy: PlatformPolicy.fromJson(policy),
      ),
    );
    await _preferences.saveSetupStep(SetupStep.region.name);
  }

  Future<void> continueRegion(List<String>? regions) async {
    if (regions != null) {
      final available = await regionCodes();
      if (!regions.every(available.contains)) {
        throw const SetupFailure('region');
      }
      final previous = await configuration();
      final connection = previous.connection.toJson();
      connection['smart'] = {
        ...previous.connection.smart.toJson(),
        'directRegions': regions,
      };
      await _save(
        ConnectionConfiguration(
          connection: ConnectionSettings.fromJson(connection),
          policy: previous.policy,
        ),
      );
    }
    // Save after configuration commits: retry is idempotent, Skip writes none.
    await _preferences.saveSetupStep(SetupStep.servers.name);
  }

  Stream<bool> watchHasServers() => _db.coreConfigDao.watchHasOutbounds();

  Future<void> finish() async {
    if (await currentStep() != SetupStep.servers) {
      throw const SetupFailure('setup');
    }
    final permission = await checkPermission();
    if (!permissionReady(permission)) {
      await _preferences.saveSetupStep(SetupStep.system.name);
      throw SetupFailure('permission', permission: permission);
    }
    // Reuse the committed policy; never activate a Raw item or connect here.
    final settings = await configuration();
    if (requiresInterface &&
        settings.policy.xrayOutboundInterfaceName.isEmpty) {
      await _preferences.saveSetupStep(SetupStep.system.name);
      throw const SetupFailure('interface');
    }
    await _preferences.saveFirstRun(false);
  }

  Future<List<String>> regionCodes() async {
    final read = _readRegionCodes;
    if (read != null) return read();
    final catalog = await (await RoutingGeodataIndex.load()).regionCatalog();
    if (catalog.regionCodes.isEmpty) throw const SetupFailure('Geodata');
    return catalog.regionCodes;
  }

  /// A Setup region lookup only. Do not persist the IP or response,
  /// send app identifiers, or use the VPN's proxy/metrics endpoint.
  Future<String?> suggestRegion() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.getUrl(
        Uri.https('ip-check-perf.radar.cloudflare.com', '/'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) return null;
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      final code = decoded is Map ? decoded['country'] : null;
      return code is String ? code.toUpperCase() : null;
    } on Exception {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<OutboundInterfaceOption>> interfaces() async {
    if (!requiresInterface) return const [];
    return queryXrayOutboundInterfaces();
  }
}
