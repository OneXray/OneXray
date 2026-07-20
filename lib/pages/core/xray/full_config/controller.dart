import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_db.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_validator.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/profile/dns_server_state.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';

enum XrayFullConfigSection { outbounds, routing, dns }

class XrayFullConfigPageState {
  final XrayFullConfigSection section;
  final int version;

  const XrayFullConfigPageState({
    this.section = XrayFullConfigSection.outbounds,
    this.version = 0,
  });

  factory XrayFullConfigPageState.initial() => const XrayFullConfigPageState();

  XrayFullConfigPageState bumped() =>
      XrayFullConfigPageState(section: section, version: version + 1);

  XrayFullConfigPageState copyWith({
    XrayFullConfigSection? section,
    int? version,
  }) {
    return XrayFullConfigPageState(
      section: section ?? this.section,
      version: version ?? this.version,
    );
  }
}

class XrayFullConfigController extends PageCubit<XrayFullConfigPageState> {
  final XrayFullConfigParams params;

  XrayFullConfigController(this.params)
    : super(XrayFullConfigPageState.initial()) {
    _queryFullConfig();
  }

  CoreConfigData? _configData;
  var _fullConfigState = XrayFullConfigState();
  var _defaultDnsServerAddress = TunSettingsState().tunDnsIPv4;

  XrayFullConfigState get fullConfigState => _fullConfigState;

  OutboundState? get primaryProxy {
    for (final outbound in _fullConfigState.outbounds.outbounds) {
      if (outbound.tag == RoutingOutboundTag.proxy.name) {
        return outbound;
      }
    }
    return null;
  }

  List<OutboundState> get customOutbounds => _fullConfigState
      .outbounds
      .outbounds
      .where((outbound) => outbound.tag != RoutingOutboundTag.proxy.name)
      .toList();

  final nameController = TextEditingController();
  final dnsClientIpController = TextEditingController();
  final dnsServeExpiredTTLController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    dnsClientIpController.dispose();
    dnsServeExpiredTTLController.dispose();
  }

  Future<void> _queryFullConfig() async {
    final tunSettings = TunSettingsState();
    await tunSettings.readFromPreferences();
    if (!isPageActive) {
      return;
    }
    _defaultDnsServerAddress = tunSettings.tunDnsIPv4;

    if (params.id != DBConstants.defaultId) {
      final db = AppDatabase();
      final config = await db.coreConfigDao.searchRow(params.id);
      if (!isPageActive) {
        return;
      }
      if (config != null) {
        _configData = config;
        final state = XrayFullConfigState();
        state.readFromDbData(config);
        _updateState(state);
      }
    } else {
      _fullConfigState.dns.servers = [_newDnsServer()];
      _initInputs(_fullConfigState);
    }
  }

  DnsServerState _newDnsServer() =>
      DnsServerState()..address = _defaultDnsServerAddress;

  void _updateState(XrayFullConfigState state) {
    _fullConfigState = state;
    _initInputs(state);
    _notifyChanged();
  }

  void _initInputs(XrayFullConfigState state) {
    nameController.text = state.name;
    dnsClientIpController.text = state.dns.clientIp;
    dnsServeExpiredTTLController.text = state.dns.serveExpiredTTL;
  }

  void updateSection(XrayFullConfigSection section) {
    _mergeVisibleInputs();
    if (section != state.section) {
      emit(state.copyWith(section: section, version: state.version + 1));
    }
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    _mergeInputToState(_fullConfigState);
    final text = JsonTool.encoder.convert(_fullConfigState.xrayJson.toJson());
    final params = XrayRawEditParams(
      AppLocalizations.of(context)!.xrayFullConfigTitle,
      text,
    );
    final newText = await context.pushScoped<String>(
      AppSecondaryDestination.xrayRawEdit,
      extra: params,
    );
    if (newText == null) {
      return;
    }
    final state = XrayFullConfigState();
    try {
      state.readFromText(newText);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationJsonInvalid,
      );
      return;
    }
    _updateState(state);
  }

  Future<void> editPrimaryProxy(BuildContext context) async {
    final current = primaryProxy;
    final outbound = current == null
        ? OutboundState()
        : _cloneOutbound(current);
    final edited = await _editOutbound(
      context,
      outbound,
      fixedTag: RoutingOutboundTag.proxy.name,
    );
    if (edited != null) {
      edited.tag = RoutingOutboundTag.proxy.name;
      _replacePrimaryProxy(edited);
    }
  }

  Future<void> importPrimaryProxy(BuildContext context) async {
    final outbound = await _selectOutbound(context);
    if (outbound == null) {
      return;
    }
    outbound.tag = RoutingOutboundTag.proxy.name;
    outbound.dialerProxy = "";
    _replacePrimaryProxy(outbound);
  }

  Future<void> addCustomOutbound(BuildContext context) async {
    final outbound = OutboundState()..tag = _nextCustomTag();
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
    if (!_isCustomTagAvailable(outbound.tag)) {
      outbound.tag = _nextCustomTag();
    }
    _appendCustomOutbound(context, outbound);
  }

  Future<void> editCustomOutbound(
    BuildContext context,
    OutboundState outbound,
  ) async {
    final edited = await _editOutbound(
      context,
      _cloneOutbound(outbound),
      editableTag: true,
    );
    if (edited != null && context.mounted) {
      _replaceCustomOutbound(context, outbound, edited);
    }
  }

  void deleteCustomOutbound(OutboundState outbound) {
    _fullConfigState.outbounds.outbounds.remove(outbound);
    _fullConfigState.outbounds.fixDnsDialerProxy();
    _notifyChanged();
  }

  Future<void> editFreedom(BuildContext context) async {
    final params = OutboundFreedomParams(_fullConfigState.outbounds.freedom);
    final freedom = await context.pushScoped<OutboundFreedomState>(
      AppSecondaryDestination.outboundFreedom,
      extra: params,
    );
    if (freedom != null) {
      _fullConfigState.outbounds.freedom = freedom;
      _notifyChanged();
    }
  }

  Future<void> editFragment(BuildContext context) async {
    final params = OutboundFragmentParams(_fullConfigState.outbounds.fragment);
    final fragment = await context.pushScoped<OutboundFragmentState>(
      AppSecondaryDestination.outboundFragment,
      extra: params,
    );
    if (fragment != null) {
      _fullConfigState.outbounds.fragment = fragment;
      _notifyChanged();
    }
  }

  Future<void> editBlackHole(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.outboundBlackHole);
  }

  Future<void> editOutboundDns(BuildContext context) async {
    final outbounds = _fullConfigState.outbounds;
    final params = OutboundDnsParams(
      outbounds.dns,
      outbounds.dnsDialerProxyTags,
    );
    final dns = await context.pushScoped<OutboundDnsState>(
      AppSecondaryDestination.outboundDns,
      extra: params,
    );
    if (dns != null) {
      outbounds.dns = dns;
      _notifyChanged();
    }
  }

  Future<OutboundState?> _editOutbound(
    BuildContext context,
    OutboundState outbound, {
    String fixedTag = "",
    bool editableTag = false,
  }) {
    final params = OutboundUIParams(
      DBConstants.defaultId,
      outbound,
      _dialerProxyTags(outbound),
      saveToDb: false,
      fixedTag: fixedTag,
      editableTag: editableTag,
    );
    return context.pushScoped<OutboundState>(
      AppSecondaryDestination.outboundUI,
      extra: params,
    );
  }

  List<String> _dialerProxyTags(OutboundState outbound) {
    return _fullConfigState.outbounds.outboundTags
        .where((tag) => tag != outbound.tag)
        .where((tag) => !_nonDialerProxyTags.contains(tag))
        .toList();
  }

  Future<OutboundState?> _selectOutbound(BuildContext context) async {
    final row = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: OutboundSelectParams(),
    );
    if (row == null) {
      return null;
    }
    final outbound = OutboundState();
    var valid = false;
    try {
      valid = outbound.readFromDbData(row);
    } catch (_) {
      valid = false;
    }
    if (!valid) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.vpnOutboundInvalid,
        );
      }
      return null;
    }
    outbound.name = row.name;
    return outbound;
  }

  void _replacePrimaryProxy(OutboundState outbound) {
    _fullConfigState.outbounds.outbounds.removeWhere(
      (item) => item.tag == RoutingOutboundTag.proxy.name,
    );
    _fullConfigState.outbounds.outbounds.insert(0, outbound);
    _notifyChanged();
  }

  void _appendCustomOutbound(BuildContext context, OutboundState outbound) {
    if (!_validateCustomTag(context, outbound.tag)) {
      return;
    }
    _fullConfigState.outbounds.outbounds.add(outbound);
    _notifyChanged();
  }

  void _replaceCustomOutbound(
    BuildContext context,
    OutboundState oldOutbound,
    OutboundState newOutbound,
  ) {
    if (!_validateCustomTag(context, newOutbound.tag, except: oldOutbound)) {
      return;
    }
    _renameOutboundReferences(oldOutbound.tag, newOutbound.tag);
    final index = _fullConfigState.outbounds.outbounds.indexOf(oldOutbound);
    if (index >= 0) {
      _fullConfigState.outbounds.outbounds[index] = newOutbound;
      _notifyChanged();
    }
  }

  void _renameOutboundReferences(String oldTag, String newTag) {
    if (oldTag == newTag) {
      return;
    }
    final rules = [
      _fullConfigState.routing.dnsQueryRule,
      _fullConfigState.routing.dnsOutRule,
      _fullConfigState.routing.dnsDoTRule,
      _fullConfigState.routing.pingRule,
      ..._fullConfigState.routing.customRules,
    ];
    for (final rule in rules) {
      if (rule.outboundTag == oldTag) {
        rule.outboundTag = newTag;
      }
    }
    for (final outbound in _fullConfigState.outbounds.outbounds) {
      if (outbound.dialerProxy == oldTag) {
        outbound.dialerProxy = newTag;
      }
    }
    if (_fullConfigState.outbounds.dns.dialerProxy == oldTag) {
      _fullConfigState.outbounds.dns.dialerProxy = newTag;
    }
  }

  bool _isCustomTagAvailable(String tag, {OutboundState? except}) {
    if (tag.isEmpty || tag == RoutingOutboundTag.proxy.name) {
      return false;
    }
    if (_systemTags.contains(tag)) {
      return false;
    }
    return !_fullConfigState.outbounds.outbounds.any(
      (outbound) => outbound != except && outbound.tag == tag,
    );
  }

  bool _validateCustomTag(
    BuildContext context,
    String tag, {
    OutboundState? except,
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
      final tag = "custom$index";
      if (_isCustomTagAvailable(tag)) {
        return tag;
      }
      index += 1;
    }
  }

  Set<String> get _systemTags => {
    RoutingOutboundTag.direct.name,
    RoutingOutboundTag.fragment.name,
    RoutingOutboundTag.block.name,
    RoutingOutboundTag.dnsOut.name,
    RoutingOutboundTag.chainProxy.name,
  };

  Set<String> get _nonDialerProxyTags => {
    RoutingOutboundTag.block.name,
    RoutingOutboundTag.dnsOut.name,
  };

  OutboundState _cloneOutbound(OutboundState outbound) {
    final clone = OutboundState();
    clone.readFromOutbound(outbound.xrayJson);
    clone.name = outbound.name;
    return clone;
  }

  void updateDomainStrategy(String value) {
    final domainStrategy = RoutingDomainStrategy.fromString(value);
    if (domainStrategy != null) {
      _fullConfigState.routing.domainStrategy = domainStrategy;
      _notifyChanged();
    }
  }

  Future<void> showSystemRule(BuildContext context, int index) async {
    switch (index) {
      case 0:
        await _showDnsQueryRule(context);
      case 1:
        await _showDnsOutRule(context);
      case 2:
        await _showDnsDoTRule(context);
    }
  }

  Future<void> _showDnsQueryRule(BuildContext context) async {
    final params = RoutingRuleDnsQueryParams(
      _fullConfigState.routing.dnsQueryRule,
      _dnsRoutingOutboundTags(),
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsQuery,
      extra: params,
    );
    if (rule != null) {
      _fullConfigState.routing.dnsQueryRule = rule;
      _notifyChanged();
    }
  }

  Future<void> _showDnsOutRule(BuildContext context) async {
    final params = RoutingRuleDnsOutParams(_fullConfigState.routing.dnsOutRule);
    await context.pushScoped(
      AppSecondaryDestination.routingRuleDnsOut,
      extra: params,
    );
  }

  Future<void> _showDnsDoTRule(BuildContext context) async {
    final params = RoutingRuleDnsDoTParams(
      _fullConfigState.routing.dnsDoTRule,
      _dnsRoutingOutboundTags(),
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsDot,
      extra: params,
    );
    if (rule != null) {
      _fullConfigState.routing.dnsDoTRule = rule;
      _notifyChanged();
    }
  }

  List<String> _dnsRoutingOutboundTags() {
    return _fullConfigState.outbounds.outboundTags
        .where((tag) => tag.isNotEmpty && tag != RoutingOutboundTag.block.name)
        .toList();
  }

  void appendCustomRule() {
    _fullConfigState.routing.customRules.add(RoutingRuleState());
    _notifyChanged();
  }

  void sortCustomRule(int oldIndex, int newIndex) {
    final rules = _fullConfigState.routing.customRules;
    final rule = rules.removeAt(oldIndex);
    rules.insert(newIndex, rule);
    _notifyChanged();
  }

  Future<void> editCustomRule(BuildContext context, int index) async {
    final params = RoutingRuleParams(
      _fullConfigState.routing.customRules[index],
      _fullConfigState.outbounds.outboundTags,
      _routingInboundTags(_fullConfigState.dns),
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRule,
      extra: params,
    );
    if (rule != null) {
      _fullConfigState.routing.customRules[index] = rule;
      _notifyChanged();
    }
  }

  void deleteCustomRule(int index) {
    _fullConfigState.routing.customRules.removeAt(index);
    _notifyChanged();
  }

  List<String> _routingInboundTags(DnsState dns) {
    return <String>{
      ...RoutingInboundTag.userVisibleNames,
      ...dns.inboundTags,
    }.toList();
  }

  void updateDisableCache(bool value) {
    _fullConfigState.dns.disableCache = value;
    _notifyChanged();
  }

  void updateServeStale(bool value) {
    _fullConfigState.dns.serveStale = value;
    _notifyChanged();
  }

  void updateDisableFallback(bool value) {
    _fullConfigState.dns.disableFallback = value;
    _notifyChanged();
  }

  void updateDisableFallbackIfMatch(bool value) {
    _fullConfigState.dns.disableFallbackIfMatch = value;
    _notifyChanged();
  }

  void updateEnableParallelQuery(bool value) {
    _fullConfigState.dns.enableParallelQuery = value;
    _notifyChanged();
  }

  void updateUseSystemHosts(bool value) {
    _fullConfigState.dns.useSystemHosts = value;
    _notifyChanged();
  }

  Future<void> editHosts(BuildContext context) async {
    final params = DnsHostsParams(_fullConfigState.dns.hosts);
    final hosts = await context.pushScoped<Map<String, List<String>>>(
      AppSecondaryDestination.dnsHosts,
      extra: params,
    );
    if (hosts != null) {
      _fullConfigState.dns.hosts = hosts;
      _notifyChanged();
    }
  }

  void appendDnsServer() {
    _fullConfigState.dns.servers.add(_newDnsServer());
    _notifyChanged();
  }

  void sortDnsServer(int oldIndex, int newIndex) {
    final servers = _fullConfigState.dns.servers;
    final server = servers.removeAt(oldIndex);
    servers.insert(newIndex, server);
    _notifyChanged();
  }

  Future<void> editDnsServer(BuildContext context, int index) async {
    final params = DnsServerParams(_fullConfigState.dns.servers[index]);
    final server = await context.pushScoped<DnsServerState>(
      AppSecondaryDestination.dnsServer,
      extra: params,
    );
    if (server != null) {
      _fullConfigState.dns.servers[index] = server;
      _notifyChanged();
    }
  }

  void deleteDnsServer(int index) {
    _fullConfigState.dns.servers.removeAt(index);
    _notifyChanged();
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(_fullConfigState);
    final checked = await _validate(context);
    if (!checked) {
      return;
    }
    if (params.id == DBConstants.defaultId) {
      final id = await _fullConfigState.insertToDb();
      PingService().schedulePingConfigIds([id]);
    } else if (_configData != null) {
      await _fullConfigState.updateToDb(_configData!);
    }
    if (context.mounted) {
      context.pop();
    }
  }

  void _mergeVisibleInputs() {
    _fullConfigState.dns.clientIp = dnsClientIpController.text;
    _fullConfigState.dns.serveExpiredTTL = dnsServeExpiredTTLController.text;
  }

  void _mergeInputToState(XrayFullConfigState state) {
    state.name = nameController.text;
    _mergeVisibleInputs();
    state.removeWhitespace();
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await _fullConfigState.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }

  void _notifyChanged() {
    if (isPageActive) {
      emit(state.bumped());
    }
  }
}
