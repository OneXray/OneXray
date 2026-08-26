import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/dns_server_dialog.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_db.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';

enum XrayMultiNodeOutboundSection { outbounds, routing, dns }

class XrayMultiNodeOutboundPageState {
  final XrayMultiNodeOutboundSection section;
  final bool loaded;
  final bool saving;

  const XrayMultiNodeOutboundPageState({
    this.section = XrayMultiNodeOutboundSection.outbounds,
    this.loaded = false,
    this.saving = false,
  });

  factory XrayMultiNodeOutboundPageState.initial() =>
      const XrayMultiNodeOutboundPageState();

  XrayMultiNodeOutboundPageState copyWith({
    XrayMultiNodeOutboundSection? section,
    bool? loaded,
    bool? saving,
  }) {
    return XrayMultiNodeOutboundPageState(
      section: section ?? this.section,
      loaded: loaded ?? this.loaded,
      saving: saving ?? this.saving,
    );
  }
}

class XrayMultiNodeOutboundController
    extends PageCubit<XrayMultiNodeOutboundPageState> {
  final XrayMultiNodeOutboundParams params;

  XrayMultiNodeOutboundController(this.params)
    : super(XrayMultiNodeOutboundPageState.initial()) {
    _queryMultiNodeOutbound();
  }

  CoreConfigData? _configData;
  Map<String, dynamic> _draft = <String, dynamic>{
    'name': XrayStateConstants.defaultName,
  };
  Map<String, dynamic> _profile = <String, dynamic>{
    'name': XrayStateConstants.defaultName,
  };
  var _defaultDnsServerAddress = TunSettingsState().tunDnsIPv4;

  Map<String, dynamic> get draft => copyXrayConfigMap(_draft);

  Map<String, dynamic>? get primaryProxy {
    for (final outbound in _outboundMaps) {
      if (outboundString(outbound, 'tag') == RoutingOutboundTag.proxy.name) {
        return outbound;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get customOutbounds => _outboundMaps
      .where((outbound) {
        final tag = outboundString(outbound, 'tag') ?? '';
        return tag != RoutingOutboundTag.proxy.name &&
            !_systemTags.contains(tag);
      })
      .toList(growable: false);

  String get routingDomainStrategy {
    final routing = _effectiveRoot('routing');
    if (routing is! Map<String, dynamic>) {
      return '';
    }
    final value = routing['domainStrategy'];
    return value is String
        ? RoutingDomainStrategy.fromString(value)?.name ?? value
        : '';
  }

  bool get routingDomainStrategyRawOnly {
    final routing = _effectiveRoot('routing');
    if (routing is! Map<String, dynamic>) {
      return false;
    }
    final value = routing['domainStrategy'];
    return value != null &&
        (value is! String || RoutingDomainStrategy.fromString(value) == null);
  }

  List<dynamic> get dnsServers {
    final dns = _effectiveRoot('dns');
    if (dns is! Map<String, dynamic>) {
      return const <dynamic>[];
    }
    final servers = dns['servers'];
    return servers is List<dynamic> ? servers : const <dynamic>[];
  }

  bool get dnsServersRawOnly {
    final dns = _effectiveRoot('dns');
    if (dns is! Map<String, dynamic>) {
      return false;
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

  final nameController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
  }

  Future<void> _queryMultiNodeOutbound() async {
    final tunSettings = TunSettingsState();
    await tunSettings.readFromPreferences();
    _defaultDnsServerAddress = tunSettings.tunDnsIPv4;
    try {
      _profile = await loadSelectedProfileMap(tunSettings);
    } catch (_) {
      return;
    }
    if (!isPageActive) {
      return;
    }

    if (params.id != DBConstants.defaultId) {
      final config = await AppDatabase().coreConfigDao.searchRow(params.id);
      if (!isPageActive) {
        return;
      }
      if (config == null) {
        return;
      }
      try {
        final next = readMultiNodeOutboundFromDbData(config);
        _configData = config;
        _updateDraft(next, loaded: true);
      } catch (_) {
        return;
      }
      return;
    }

    final next = <String, dynamic>{'name': XrayStateConstants.defaultName};
    if (_profile.containsKey('outbounds')) {
      next['outbounds'] = copyXrayConfigMap(_profile)['outbounds'];
    }
    _updateDraft(next, loaded: true);
  }

  void _updateDraft(Map<String, dynamic> next, {bool? loaded}) {
    _draft = next;
    nameController.text = multiNodeOutboundName(next);
    _notifyChanged(loaded: loaded);
  }

  void updateSection(XrayMultiNodeOutboundSection section) {
    if (section != state.section) {
      emit(state.copyWith(section: section));
    }
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    final next = _draftWithVisibleName();
    late final String text;
    try {
      text = encodeMultiNodeOutboundMap(next);
    } catch (_) {
      _showJsonInvalid(context);
      return;
    }
    final params = XrayRawEditParams(
      AppLocalizations.of(context)!.xrayMultiNodeOutboundTitle,
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
      final edited = readMultiNodeOutboundFromText(newText);
      _updateDraft(edited);
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  Future<void> editRoot(BuildContext context, String root) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    late final Map<String, dynamic> base;
    late final String text;
    try {
      base = _draftWithVisibleName();
      _inheritRootIfMissing(base, root);
      text = encodeXrayRootEditor(base, root);
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
      final edited = applyXrayRootEditor(base, root, newText);
      _updateDraft(edited);
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  String rootSummary(String root) {
    if (!_draft.containsKey(root)) {
      return '-';
    }
    final value = _draft[root];
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

  Future<void> editPrimaryProxy(BuildContext context) async {
    final current = primaryProxy;
    final outbound = current == null
        ? newOutboundMap()
        : copyOutboundMap(current);
    final edited = await _editOutbound(
      context,
      outbound,
      fixedTag: RoutingOutboundTag.proxy.name,
    );
    if (edited != null) {
      setOutboundTag(edited, RoutingOutboundTag.proxy.name);
      _replacePrimaryProxy(edited);
    }
  }

  Future<void> importPrimaryProxy(BuildContext context) async {
    final outbound = await _selectOutbound(context);
    if (outbound == null) {
      return;
    }
    setOutboundTag(outbound, RoutingOutboundTag.proxy.name);
    removeOutboundDialerProxy(outbound);
    _replacePrimaryProxy(outbound);
  }

  Future<void> addCustomOutbound(BuildContext context) async {
    final outbound = newOutboundMap(tag: _nextCustomTag());
    final edited = await _editOutbound(context, outbound, editableTag: true);
    if (edited != null && context.mounted) {
      _appendCustomOutbound(context, edited);
    }
  }

  Future<void> importCustomOutbound(BuildContext context) async {
    final outbound = await _selectOutbound(context);
    if (outbound == null || !context.mounted) {
      return;
    }
    if (!_isCustomTagAvailable(outboundString(outbound, 'tag') ?? '')) {
      setOutboundTag(outbound, _nextCustomTag());
    }
    _appendCustomOutbound(context, outbound);
  }

  Future<void> editCustomOutbound(
    BuildContext context,
    Map<String, dynamic> outbound,
  ) async {
    final edited = await _editOutbound(
      context,
      copyOutboundMap(outbound),
      editableTag: true,
    );
    if (edited != null && context.mounted) {
      _replaceCustomOutbound(context, outbound, edited);
    }
  }

  void deleteCustomOutbound(
    BuildContext context,
    Map<String, dynamic> outbound,
  ) {
    final tag = outboundString(outbound, 'tag') ?? '';
    if (_outboundTagIsReferenced(tag)) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationOutboundInUse,
      );
      return;
    }
    final index = _rawOutbounds.indexWhere((item) => identical(item, outbound));
    if (index < 0) {
      return;
    }
    final next = copyXrayConfigMap(_draft);
    _ensureOutbounds(next).removeAt(index);
    _draft = next;
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> _editOutbound(
    BuildContext context,
    Map<String, dynamic> outbound, {
    String fixedTag = '',
    bool editableTag = false,
  }) {
    final params = OutboundUIParams(
      DBConstants.defaultId,
      outbound,
      saveToDb: false,
      fixedTag: fixedTag,
      editableTag: editableTag,
    );
    return context.pushScoped<Map<String, dynamic>>(
      AppSecondaryDestination.outboundUI,
      extra: params,
    );
  }

  Future<Map<String, dynamic>?> _selectOutbound(BuildContext context) async {
    final row = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: OutboundSelectParams(),
    );
    if (row == null) {
      return null;
    }
    Map<String, dynamic> outbound;
    try {
      outbound = readOutboundFromDbData(row);
      requireCanonicalOutbound(outbound);
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.vpnOutboundInvalid,
        );
      }
      return null;
    }
    if (outboundString(outbound, 'name')?.isNotEmpty != true) {
      outbound['name'] = row.name;
    }
    return outbound;
  }

  void _replacePrimaryProxy(Map<String, dynamic> outbound) {
    final next = copyXrayConfigMap(_draft);
    final outbounds = _ensureOutbounds(next);
    final index = outbounds.indexWhere(
      (item) =>
          item is Map<String, dynamic> &&
          outboundString(item, 'tag') == RoutingOutboundTag.proxy.name,
    );
    if (index < 0) {
      outbounds.insert(0, copyOutboundMap(outbound));
    } else {
      outbounds[index] = copyOutboundMap(outbound);
    }
    _draft = next;
    _notifyChanged();
  }

  void _appendCustomOutbound(
    BuildContext context,
    Map<String, dynamic> outbound,
  ) {
    if (!_validateCustomTag(context, outboundString(outbound, 'tag') ?? '')) {
      return;
    }
    final next = copyXrayConfigMap(_draft);
    _ensureOutbounds(next).add(copyOutboundMap(outbound));
    _draft = next;
    _notifyChanged();
  }

  void _replaceCustomOutbound(
    BuildContext context,
    Map<String, dynamic> oldOutbound,
    Map<String, dynamic> newOutbound,
  ) {
    final index = _rawOutbounds.indexWhere(
      (item) => identical(item, oldOutbound),
    );
    if (index < 0) {
      return;
    }
    final oldTag = outboundString(oldOutbound, 'tag') ?? '';
    final newTag = outboundString(newOutbound, 'tag') ?? '';
    if (!_validateCustomTag(context, newTag, except: oldOutbound)) {
      return;
    }
    if (oldTag != newTag) {
      final oldTagCount = _outboundMaps
          .where((outbound) => outboundString(outbound, 'tag') == oldTag)
          .length;
      if (oldTag.isEmpty || oldTagCount != 1) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.vpnOutboundInvalid,
        );
        return;
      }
      if (_hasSelectorReference(oldTag)) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.validationOutboundInUse,
        );
        return;
      }
    }

    final next = copyXrayConfigMap(_draft);
    final outbounds = _ensureOutbounds(next);
    outbounds[index] = copyOutboundMap(newOutbound);
    _renameOutboundReferences(next, oldTag, newTag);
    _draft = next;
    _notifyChanged();
  }

  void _renameOutboundReferences(
    Map<String, dynamic> config,
    String oldTag,
    String newTag,
  ) {
    if (oldTag == newTag) {
      return;
    }

    final routing = _copyEffectiveRoot(config, 'routing');
    var routingChanged = false;
    if (routing is Map<String, dynamic>) {
      final rules = routing['rules'];
      if (rules is List<dynamic>) {
        for (final rule in rules) {
          if (rule is Map<String, dynamic> && rule['outboundTag'] == oldTag) {
            rule['outboundTag'] = newTag;
            routingChanged = true;
          }
        }
      }
      final balancers = routing['balancers'];
      if (balancers is List<dynamic>) {
        for (final balancer in balancers.whereType<Map<String, dynamic>>()) {
          if (balancer['fallbackTag'] == oldTag) {
            balancer['fallbackTag'] = newTag;
            routingChanged = true;
          }
        }
      }
    }
    if (routingChanged) {
      config['routing'] = routing;
    }

    final outbounds = config['outbounds'];
    if (outbounds is! List<dynamic>) {
      return;
    }
    for (final outbound in outbounds) {
      if (outbound is! Map<String, dynamic>) {
        continue;
      }
      if (outboundDialerProxy(outbound) == oldTag) {
        setOutboundDialerProxy(outbound, newTag);
      }
      final proxySettings = outbound['proxySettings'];
      if (proxySettings is Map<String, dynamic> &&
          proxySettings['tag'] == oldTag) {
        proxySettings['tag'] = newTag;
      }
    }
  }

  bool _outboundTagIsReferenced(String tag) {
    if (tag.isEmpty) {
      return false;
    }
    final config = applyMultiNodeOutboundOverlay(_profile, _draft);
    final routing = config['routing'];
    if (routing is Map<String, dynamic>) {
      final rules = routing['rules'];
      if (rules is List<dynamic> &&
          rules.whereType<Map>().any((rule) => rule['outboundTag'] == tag)) {
        return true;
      }
      final balancers = routing['balancers'];
      if (balancers is List<dynamic>) {
        for (final balancer in balancers.whereType<Map>()) {
          if (balancer['fallbackTag'] == tag ||
              _selectorContains(balancer['selector'], tag)) {
            return true;
          }
        }
      }
    }
    final outbounds = config['outbounds'];
    if (outbounds is List<dynamic>) {
      for (final outbound in outbounds.whereType<Map<String, dynamic>>()) {
        if (outboundString(outbound, 'tag') == tag) {
          continue;
        }
        if (outboundDialerProxy(outbound) == tag) {
          return true;
        }
        final proxySettings = outbound['proxySettings'];
        if (proxySettings is Map<String, dynamic> &&
            proxySettings['tag'] == tag) {
          return true;
        }
      }
    }
    for (final root in const ['observatory', 'burstObservatory']) {
      final observatory = config[root];
      if (observatory is Map<String, dynamic> &&
          _selectorContains(observatory['subjectSelector'], tag)) {
        return true;
      }
    }
    return false;
  }

  bool _hasSelectorReference(String tag) {
    final config = applyMultiNodeOutboundOverlay(_profile, _draft);
    final routing = config['routing'];
    if (routing is Map<String, dynamic>) {
      final balancers = routing['balancers'];
      if (balancers is List<dynamic> &&
          balancers.whereType<Map>().any(
            (balancer) => _selectorContains(balancer['selector'], tag),
          )) {
        return true;
      }
    }
    for (final root in const ['observatory', 'burstObservatory']) {
      final observatory = config[root];
      if (observatory is Map<String, dynamic> &&
          _selectorContains(observatory['subjectSelector'], tag)) {
        return true;
      }
    }
    return false;
  }

  bool _selectorContains(dynamic value, String tag) =>
      value is List<dynamic> && value.whereType<String>().any(tag.startsWith);

  bool _isCustomTagAvailable(String tag, {Map<String, dynamic>? except}) {
    if (tag.isEmpty || tag == RoutingOutboundTag.proxy.name) {
      return false;
    }
    if (_systemTags.contains(tag)) {
      return false;
    }
    return !_outboundMaps.any(
      (outbound) =>
          !identical(outbound, except) &&
          outboundString(outbound, 'tag') == tag,
    );
  }

  bool _validateCustomTag(
    BuildContext context,
    String tag, {
    Map<String, dynamic>? except,
  }) {
    if (tag.isEmpty) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationTagRequired,
      );
      return false;
    }
    if (!_isCustomTagAvailable(tag, except: except)) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationTagUnique,
      );
      return false;
    }
    return true;
  }

  String _nextCustomTag() {
    var index = 1;
    while (true) {
      final tag = 'custom$index';
      if (_isCustomTagAvailable(tag)) {
        return tag;
      }
      index += 1;
    }
  }

  void updateDomainStrategy(String value) {
    if (routingDomainStrategyRawOnly ||
        RoutingDomainStrategy.fromString(value) == null) {
      return;
    }
    final next = copyXrayConfigMap(_draft);
    _inheritRootIfMissing(next, 'routing');
    final current = next['routing'];
    final routing = current is Map<String, dynamic>
        ? current
        : <String, dynamic>{};
    routing['domainStrategy'] = value;
    next['routing'] = routing;
    _draft = next;
    _notifyChanged();
  }

  bool updateDnsServer(int? index, String address, String port) {
    final parsedPort = port.isEmpty ? null : int.tryParse(port);
    if (port.isNotEmpty && parsedPort == null) {
      return false;
    }
    final next = copyXrayConfigMap(_draft);
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
    _draft = next;
    _notifyChanged();
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
    final edited = await showDnsServerEditDialog(context, server);
    if (edited != null && context.mounted) {
      if (!updateDnsServer(index, edited.address, edited.port)) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.validationPortInvalid,
        );
      }
    }
  }

  void deleteDnsServer(int index) {
    final next = copyXrayConfigMap(_draft);
    final servers = _ensureDnsServers(next);
    if (servers == null) {
      return;
    }
    if (index < 0 || index >= servers.length) {
      return;
    }
    servers.removeAt(index);
    _draft = next;
    _notifyChanged();
  }

  void reorderDnsServer(int oldIndex, int newIndex) {
    final next = copyXrayConfigMap(_draft);
    final servers = _ensureDnsServers(next);
    if (servers == null) {
      return;
    }
    if (oldIndex < 0 || oldIndex >= servers.length) {
      return;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final server = servers.removeAt(oldIndex);
    servers.insert(newIndex, server);
    _draft = next;
    _notifyChanged();
  }

  Future<void> save(BuildContext context) async {
    if (!_ensureLoaded(context) || state.saving) {
      return;
    }
    emit(state.copyWith(saving: true));
    final next = _draftWithVisibleName();
    try {
      final tunSettings = TunSettingsState();
      await tunSettings.readFromPreferences();
      final profile = await loadSelectedProfileMap(tunSettings);
      final validation = await validateMultiNodeOutbound(next, profile);
      if (!context.mounted) {
        return;
      }
      if (!validation.item1) {
        ContextAlert.showToast(context, validation.item2);
        return;
      }

      _draft = next;
      if (params.id == DBConstants.defaultId) {
        final id = await insertMultiNodeOutbound(_draft);
        PingService().schedulePingConfigIds([id]);
      } else if (_configData != null) {
        if (!await updateMultiNodeOutbound(_draft, _configData!)) {
          throw StateError('Multi-node Outbound no longer exists');
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

  Map<String, dynamic> _draftWithVisibleName() {
    final next = copyXrayConfigMap(_draft);
    next['name'] = nameController.text;
    return next;
  }

  List<dynamic> get _rawOutbounds {
    final outbounds = _effectiveRoot('outbounds');
    return outbounds is List<dynamic> ? outbounds : const <dynamic>[];
  }

  List<Map<String, dynamic>> get _outboundMaps =>
      _rawOutbounds.whereType<Map<String, dynamic>>().toList(growable: false);

  List<dynamic> _ensureOutbounds(Map<String, dynamic> config) {
    _inheritRootIfMissing(config, 'outbounds');
    final outbounds = config['outbounds'];
    if (outbounds is List<dynamic>) {
      return outbounds;
    }
    final next = <dynamic>[];
    config['outbounds'] = next;
    return next;
  }

  List<dynamic>? _ensureDnsServers(Map<String, dynamic> config) {
    _inheritRootIfMissing(config, 'dns');
    final currentDns = config['dns'];
    final dns = currentDns is Map<String, dynamic>
        ? currentDns
        : <String, dynamic>{};
    final currentServers = dns['servers'];
    if (currentServers != null && currentServers is! List<dynamic>) {
      return null;
    }
    final servers = currentServers as List<dynamic>? ?? <dynamic>[];
    dns['servers'] = servers;
    config['dns'] = dns;
    return servers;
  }

  Set<String> get _systemTags => {
    RoutingOutboundTag.direct.name,
    RoutingOutboundTag.fragment.name,
    RoutingOutboundTag.block.name,
    RoutingOutboundTag.dnsOut.name,
    RoutingOutboundTag.chainProxy.name,
  };

  void _showJsonInvalid(BuildContext context) {
    ContextAlert.showToast(
      context,
      AppLocalizations.of(context)!.validationJsonInvalid,
    );
  }

  bool _ensureLoaded(BuildContext context) {
    if (state.loaded &&
        (params.id == DBConstants.defaultId || _configData != null)) {
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
      emit(state.copyWith(loaded: loaded));
    }
  }

  dynamic _effectiveRoot(String root) =>
      _draft.containsKey(root) ? _draft[root] : _profile[root];

  void _inheritRootIfMissing(Map<String, dynamic> config, String root) {
    if (config.containsKey(root) || !_profile.containsKey(root)) {
      return;
    }
    config[root] = copyXrayConfigMap(_profile)[root];
  }

  dynamic _copyEffectiveRoot(Map<String, dynamic> config, String root) {
    final source = config.containsKey(root) ? config : _profile;
    return copyXrayConfigMap(source)[root];
  }
}
