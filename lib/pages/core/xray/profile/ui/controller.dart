import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/state_db.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';

enum XrayProfileUISection {
  inbounds,
  outbounds,
  routing,
  dns,
  fakeDns,
  log,
  advanced,
}

const xrayProfileAdvancedRoots = <String>[
  'policy',
  'metrics',
  'stats',
  'observatory',
  'burstObservatory',
  'version',
  'geodata',
];

const xrayProfileReadOnlyRoots = <String>{'metrics', 'stats'};

class XrayProfileUIPageState {
  final XrayProfileUISection section;
  final bool loaded;
  final bool saving;
  final int version;

  const XrayProfileUIPageState({
    this.section = XrayProfileUISection.inbounds,
    this.loaded = false,
    this.saving = false,
    this.version = 0,
  });

  factory XrayProfileUIPageState.initial() => const XrayProfileUIPageState();

  XrayProfileUIPageState copyWith({
    XrayProfileUISection? section,
    bool? loaded,
    bool? saving,
    int? version,
  }) {
    return XrayProfileUIPageState(
      section: section ?? this.section,
      loaded: loaded ?? this.loaded,
      saving: saving ?? this.saving,
      version: version ?? this.version,
    );
  }
}

class XrayProfileUIController extends PageCubit<XrayProfileUIPageState> {
  final XrayProfileUIParams params;

  XrayProfileUIController(this.params)
    : super(XrayProfileUIPageState.initial()) {
    nameController.addListener(_updateVisibleName);
    _queryXrayProfile();
  }

  CoreConfigData? _profileData;
  Map<String, dynamic> _document = <String, dynamic>{};
  var _defaultDnsServerAddress = TunSettingsState().tunDnsIPv4;
  var _syncingName = false;

  final nameController = TextEditingController();

  Map<String, dynamic> get document => _copyDocument(_document);

  String get routingDomainStrategy {
    final routing = _document['routing'];
    if (routing is! Map<String, dynamic>) {
      return RoutingDomainStrategy.asIs.name;
    }
    final value = routing['domainStrategy'];
    return value is String
        ? RoutingDomainStrategy.fromString(value)?.name ?? value
        : RoutingDomainStrategy.asIs.name;
  }

  bool get routingRawOnly {
    final routing = _document['routing'];
    if (routing == null) {
      return false;
    }
    if (routing is! Map<String, dynamic>) {
      return true;
    }
    final value = routing['domainStrategy'];
    return value != null &&
        (value is! String || RoutingDomainStrategy.fromString(value) == null);
  }

  List<dynamic> get dnsServers {
    final dns = _document['dns'];
    if (dns is! Map<String, dynamic>) {
      return const <dynamic>[];
    }
    final servers = dns['servers'];
    return servers is List<dynamic> ? servers : const <dynamic>[];
  }

  bool get dnsServersRawOnly {
    final dns = _document['dns'];
    if (dns == null) {
      return false;
    }
    if (dns is! Map<String, dynamic>) {
      return true;
    }
    final servers = dns['servers'];
    return servers != null && servers is! List<dynamic>;
  }

  bool isEditableDnsServer(dynamic server) {
    if (server is! Map<String, dynamic>) {
      return false;
    }
    final address = server['address'];
    final port = server['port'];
    return (address == null || address is String) &&
        (port == null || port is int);
  }

  bool get fakeDnsRawOnly {
    final fakeDns = _document['fakeDns'];
    if (fakeDns == null) {
      return false;
    }
    if (fakeDns is! List<dynamic>) {
      return true;
    }
    var ipv4Count = 0;
    var ipv6Count = 0;
    for (final value in fakeDns) {
      if (value is! Map<String, dynamic>) {
        return true;
      }
      final address = _fakeDnsAddress(value);
      final poolSize = value['poolSize'];
      if (address == null || (poolSize != null && poolSize is! int)) {
        return true;
      }
      if (address.type == InternetAddressType.IPv4) {
        ipv4Count += 1;
      } else if (address.type == InternetAddressType.IPv6) {
        ipv6Count += 1;
      }
    }
    return ipv4Count > 1 || ipv6Count > 1;
  }

  Map<String, dynamic>? fakeDnsPool(bool ipv6) {
    if (fakeDnsRawOnly) {
      return null;
    }
    final fakeDns = _document['fakeDns'];
    if (fakeDns is! List<dynamic>) {
      return null;
    }
    final expected = ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4;
    for (final value in fakeDns.whereType<Map<String, dynamic>>()) {
      if (_fakeDnsAddress(value)?.type == expected) {
        return value;
      }
    }
    return null;
  }

  String get logLevel {
    final log = _document['log'];
    if (log is! Map<String, dynamic>) {
      return XrayLogLevel.none.name;
    }
    final value = log['loglevel'];
    return value is String ? value : XrayLogLevel.none.name;
  }

  bool get dnsLog {
    final log = _document['log'];
    return log is Map<String, dynamic> && log['dnsLog'] is bool
        ? log['dnsLog'] as bool
        : false;
  }

  String get maskAddress {
    final log = _document['log'];
    if (log is! Map<String, dynamic>) {
      return XrayLogMaskAddress.none.name;
    }
    final value = log['maskAddress'];
    return value is String ? value : XrayLogMaskAddress.none.name;
  }

  bool get logRawOnly {
    final log = _document['log'];
    if (log == null) {
      return false;
    }
    if (log is! Map<String, dynamic>) {
      return true;
    }
    final level = log['loglevel'];
    final dns = log['dnsLog'];
    final mask = log['maskAddress'];
    return level != null &&
            (level is! String || XrayLogLevel.fromString(level) == null) ||
        dns != null && dns is! bool ||
        mask != null &&
            (mask is! String || XrayLogMaskAddress.fromString(mask) == null);
  }

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
  }

  Future<void> _queryXrayProfile() async {
    final tunSettings = TunSettingsState();
    await tunSettings.readFromPreferences();
    if (!isPageActive) {
      return;
    }
    _defaultDnsServerAddress = tunSettings.tunDnsIPv4;

    if (params.id == DBConstants.defaultId) {
      _replaceDocument(newProfileMap(_defaultDnsServerAddress), loaded: true);
      return;
    }

    final profile = await AppDatabase().coreConfigDao.searchRow(params.id);
    if (!isPageActive || profile == null) {
      return;
    }
    try {
      final next = readProfileMapFromDbData(profile);
      _profileData = profile;
      _replaceDocument(next, loaded: true);
    } catch (_) {
      return;
    }
  }

  void updateSection(XrayProfileUISection section) {
    if (section != state.section) {
      emit(state.copyWith(section: section, version: state.version + 1));
    }
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    late final String text;
    try {
      text = encodeProfileMap(_document);
    } catch (_) {
      _showJsonInvalid(context);
      return;
    }
    final params = XrayRawEditParams(
      AppLocalizations.of(context)!.xrayProfileUIPageTitle,
      text,
    );
    final newText = await context.pushScoped<String>(
      AppSecondaryDestination.xrayRawEdit,
      extra: params,
    );
    if (newText == null) {
      return;
    }
    try {
      _replaceDocument(readProfileMapFromText(newText));
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  Future<void> editRoot(BuildContext context, String root) async {
    if (xrayProfileReadOnlyRoots.contains(root)) {
      return;
    }
    if (!_ensureLoaded(context)) {
      return;
    }
    late final String text;
    try {
      text = encodeXrayRootEditor(_document, root);
    } catch (_) {
      _showJsonInvalid(context);
      return;
    }
    final params = XrayRawEditParams(
      '${AppLocalizations.of(context)!.menuEdit} $root JSON',
      text,
    );
    final newText = await context.pushScoped<String>(
      AppSecondaryDestination.xrayRawEdit,
      extra: params,
    );
    if (newText == null) {
      return;
    }
    try {
      _replaceDocument(applyXrayRootEditor(_document, root, newText));
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  String rootSummary(String root) {
    if (!_document.containsKey(root)) {
      return '-';
    }
    final value = _document[root];
    if (value == null) {
      return 'null';
    }
    if (value is List<dynamic>) {
      return '${value.length}';
    }
    if (value is Map<String, dynamic>) {
      return '${value.length}';
    }
    return '$value';
  }

  String rootJson(String root) {
    if (_document.containsKey(root)) {
      return jsonEncode(_document[root]);
    }
    final value = switch (root) {
      'metrics' => defaultProfileMetrics,
      'stats' => defaultProfileStats,
      _ => null,
    };
    return value == null ? '-' : jsonEncode(value);
  }

  void updateDomainStrategy(String value) {
    if (routingRawOnly || RoutingDomainStrategy.fromString(value) == null) {
      return;
    }
    _updateMapRoot('routing', (routing) {
      routing['domainStrategy'] = value;
    });
  }

  bool updateDnsServer(int? index, String address, String port) {
    final parsedPort = port.isEmpty ? null : int.tryParse(port);
    if (port.isNotEmpty && parsedPort == null) {
      return false;
    }
    final next = _copyDocument(_document);
    final servers = _ensureDnsServers(next);
    if (servers == null) {
      return false;
    }
    if (index != null &&
        (index < 0 ||
            index >= servers.length ||
            !isEditableDnsServer(servers[index]))) {
      return false;
    }
    final server = index == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(servers[index] as Map<String, dynamic>);
    server['address'] = address;
    if (parsedPort == null) {
      server.remove('port');
    } else {
      server['port'] = parsedPort;
    }
    if (index == null) {
      servers.add(server);
    } else {
      servers[index] = server;
    }
    _replaceDocument(next);
    return true;
  }

  void addDnsServer() {
    updateDnsServer(null, _defaultDnsServerAddress, '');
  }

  Future<void> editDnsServer(BuildContext context, int index) async {
    final servers = dnsServers;
    if (index < 0 ||
        index >= servers.length ||
        !isEditableDnsServer(servers[index])) {
      return;
    }
    final server = servers[index] as Map<String, dynamic>;
    var address = server['address'] as String? ?? '';
    var port = server['port']?.toString() ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.dnsPageServers),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: address,
                onChanged: (value) => address = value,
                decoration: InputDecoration(
                  labelText: l10n.dnsServerPageAddress,
                  hintText: l10n.dnsServerPageAddressExample,
                ),
              ),
              TextFormField(
                initialValue: port,
                onChanged: (value) => port = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.dnsServerPagePort,
                  hintText: l10n.dnsServerPagePortExample,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.buttonSave),
            ),
          ],
        );
      },
    );
    if (accepted == true && context.mounted) {
      if (!updateDnsServer(index, address, port)) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.validationPortInvalid,
        );
      }
    }
  }

  void deleteDnsServer(int index) {
    final next = _copyDocument(_document);
    final servers = _ensureDnsServers(next);
    if (servers == null || index < 0 || index >= servers.length) {
      return;
    }
    servers.removeAt(index);
    _replaceDocument(next);
  }

  void reorderDnsServer(int oldIndex, int newIndex) {
    final next = _copyDocument(_document);
    final servers = _ensureDnsServers(next);
    if (servers == null || oldIndex < 0 || oldIndex >= servers.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final server = servers.removeAt(oldIndex);
    servers.insert(newIndex, server);
    _replaceDocument(next);
  }

  bool updateFakeDnsPool(bool ipv6, String ipPool, String poolSize) {
    final parsedPoolSize = poolSize.isEmpty ? null : int.tryParse(poolSize);
    final address = InternetAddress.tryParse(ipPool.split('/').first);
    final expected = ipv6 ? InternetAddressType.IPv6 : InternetAddressType.IPv4;
    if (fakeDnsRawOnly ||
        address?.type != expected ||
        (poolSize.isNotEmpty && parsedPoolSize == null)) {
      return false;
    }

    final next = _copyDocument(_document);
    final current = next['fakeDns'];
    final pools = current is List<dynamic> ? current : <dynamic>[];
    final index = pools.indexWhere(
      (value) =>
          value is Map<String, dynamic> &&
          _fakeDnsAddress(value)?.type == expected,
    );
    final pool = index < 0
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(pools[index] as Map<String, dynamic>);
    pool['ipPool'] = ipPool;
    if (parsedPoolSize == null) {
      pool.remove('poolSize');
    } else {
      pool['poolSize'] = parsedPoolSize;
    }
    if (index < 0) {
      pools.add(pool);
    } else {
      pools[index] = pool;
    }
    next['fakeDns'] = pools;
    _replaceDocument(next);
    return true;
  }

  Future<void> editFakeDnsPool(
    BuildContext context, {
    required bool ipv6,
  }) async {
    final pool = fakeDnsPool(ipv6);
    var ipPool = pool?['ipPool'] as String? ?? '';
    var poolSize = pool?['poolSize']?.toString() ?? '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(ipv6 ? l10n.fakeDnsPageIPv6 : l10n.fakeDnsPageIPv4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: ipPool,
                onChanged: (value) => ipPool = value,
                decoration: InputDecoration(labelText: l10n.fakeDnsPageIpPool),
              ),
              TextFormField(
                initialValue: poolSize,
                onChanged: (value) => poolSize = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.fakeDnsPagePoolSize,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.buttonSave),
            ),
          ],
        );
      },
    );
    if (accepted == true && context.mounted) {
      if (!updateFakeDnsPool(ipv6, ipPool, poolSize)) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.fakeDnsValidationIpPoolInvalid,
        );
      }
    }
  }

  void updateLogLevel(String value) {
    if (logRawOnly || XrayLogLevel.fromString(value) == null) {
      return;
    }
    _updateMapRoot('log', (log) {
      log['loglevel'] = value;
    });
  }

  void updateDnsLog(bool value) {
    if (logRawOnly) {
      return;
    }
    _updateMapRoot('log', (log) {
      log['dnsLog'] = value;
    });
  }

  void updateMaskAddress(String value) {
    if (logRawOnly || XrayLogMaskAddress.fromString(value) == null) {
      return;
    }
    _updateMapRoot('log', (log) {
      log['maskAddress'] = value;
    });
  }

  Future<void> save(BuildContext context) async {
    if (!_ensureLoaded(context) || state.saving) {
      return;
    }
    emit(state.copyWith(saving: true));
    try {
      final validation = await validateProfile(_document);
      if (!context.mounted) {
        return;
      }
      if (!validation.item1) {
        ContextAlert.showToast(context, validation.item2);
        return;
      }

      if (params.id == DBConstants.defaultId) {
        await insertProfile(_document);
      } else if (_profileData != null) {
        if (!await updateProfile(_document, _profileData!)) {
          throw StateError('Xray Profile no longer exists');
        }
        final eventBus = AppEventBus.instance;
        if (params.id == eventBus.state.xrayProfileId) {
          eventBus.updateXrayProfileId(eventBus.state.xrayProfileId);
        }
      }
      if (context.mounted) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted && isPageActive) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.vpnOutboundInvalid,
        );
      }
    } finally {
      if (isPageActive) {
        emit(state.copyWith(saving: false));
      }
    }
  }

  void _updateMapRoot(
    String root,
    void Function(Map<String, dynamic> value) update,
  ) {
    final next = _copyDocument(_document);
    final current = next[root];
    final value = current is Map<String, dynamic>
        ? current
        : <String, dynamic>{};
    update(value);
    next[root] = value;
    _replaceDocument(next);
  }

  List<dynamic>? _ensureDnsServers(Map<String, dynamic> document) {
    final currentDns = document['dns'];
    if (currentDns != null && currentDns is! Map<String, dynamic>) {
      return null;
    }
    final dns = currentDns is Map<String, dynamic>
        ? currentDns
        : <String, dynamic>{};
    final currentServers = dns['servers'];
    if (currentServers != null && currentServers is! List<dynamic>) {
      return null;
    }
    final servers = currentServers as List<dynamic>? ?? <dynamic>[];
    dns['servers'] = servers;
    document['dns'] = dns;
    return servers;
  }

  InternetAddress? _fakeDnsAddress(Map<String, dynamic> pool) {
    final ipPool = pool['ipPool'];
    if (ipPool is! String || ipPool.isEmpty) {
      return null;
    }
    return InternetAddress.tryParse(ipPool.split('/').first);
  }

  void _updateVisibleName() {
    if (_syncingName || !state.loaded) {
      return;
    }
    final next = _copyDocument(_document);
    next['name'] = nameController.text;
    _document = next;
  }

  void _replaceDocument(Map<String, dynamic> next, {bool? loaded}) {
    _document = _copyDocument(next);
    _syncingName = true;
    nameController.text = _document['name'] is String
        ? _document['name'] as String
        : '';
    _syncingName = false;
    _notifyChanged(loaded: loaded);
  }

  void _showJsonInvalid(BuildContext context) {
    ContextAlert.showToast(
      context,
      AppLocalizations.of(context)!.validationJsonInvalid,
    );
  }

  bool _ensureLoaded(BuildContext context) {
    if (state.loaded &&
        (params.id == DBConstants.defaultId || _profileData != null)) {
      return true;
    }
    ContextAlert.showToast(
      context,
      AppLocalizations.of(context)!.vpnOutboundInvalid,
    );
    return false;
  }

  void _notifyChanged({bool? loaded}) {
    if (isPageActive) {
      emit(state.copyWith(loaded: loaded, version: state.version + 1));
    }
  }

  Map<String, dynamic> _copyDocument(Map<String, dynamic> source) =>
      jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
}
