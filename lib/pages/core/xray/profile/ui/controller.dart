import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_ping/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/profile/dns_server_state.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/fake_dns_state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_db.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
import 'package:onexray/service/xray/profile/state_writer.dart';

enum XrayProfileUISection { inbounds, outbounds, routing, dns, fakeDns, log }

class XrayProfileUIPageState {
  final XrayProfileUISection section;
  final int version;

  const XrayProfileUIPageState({
    this.section = XrayProfileUISection.inbounds,
    this.version = 0,
  });

  factory XrayProfileUIPageState.initial() => const XrayProfileUIPageState();

  XrayProfileUIPageState bumped() =>
      XrayProfileUIPageState(section: section, version: version + 1);

  XrayProfileUIPageState copyWith({
    XrayProfileUISection? section,
    int? version,
  }) {
    return XrayProfileUIPageState(
      section: section ?? this.section,
      version: version ?? this.version,
    );
  }
}

class XrayProfileUIController extends PageCubit<XrayProfileUIPageState> {
  final XrayProfileUIParams params;

  XrayProfileUIController(this.params)
    : super(XrayProfileUIPageState.initial()) {
    _queryXrayProfile();
  }

  CoreConfigData? _xrayProfileData;
  var _xrayProfileState = XrayProfileState();
  var _defaultDnsServerAddress = TunSettingsState().tunDnsIPv4;

  XrayProfileState get profileState => _xrayProfileState;

  final nameController = TextEditingController();
  final dnsClientIpController = TextEditingController();
  final dnsServeExpiredTTLController = TextEditingController();
  final fakeDnsIpv4IpPoolController = TextEditingController();
  final fakeDnsIpv4PoolSizeController = TextEditingController();
  final fakeDnsIpv6IpPoolController = TextEditingController();
  final fakeDnsIpv6PoolSizeController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    dnsClientIpController.dispose();
    dnsServeExpiredTTLController.dispose();
    fakeDnsIpv4IpPoolController.dispose();
    fakeDnsIpv4PoolSizeController.dispose();
    fakeDnsIpv6IpPoolController.dispose();
    fakeDnsIpv6PoolSizeController.dispose();
  }

  Future<void> _queryXrayProfile() async {
    final tunSettings = TunSettingsState();
    await tunSettings.readFromPreferences();
    if (!isPageActive) {
      return;
    }
    _defaultDnsServerAddress = tunSettings.tunDnsIPv4;

    if (params.id != DBConstants.defaultId) {
      final db = AppDatabase();
      final xrayProfile = await db.coreConfigDao.searchRow(params.id);
      if (!isPageActive) {
        return;
      }
      if (xrayProfile != null) {
        _xrayProfileData = xrayProfile;
        final state = XrayProfileState();
        state.readFromDbData(xrayProfile);
        _updateState(state);
      }
    } else {
      _xrayProfileState.dns.servers = [_newDnsServer()];
      _initInputs(_xrayProfileState);
    }
  }

  DnsServerState _newDnsServer() =>
      DnsServerState()..address = _defaultDnsServerAddress;

  void _updateState(XrayProfileState state) {
    _xrayProfileState = state;
    _initInputs(state);
    _notifyChanged();
  }

  void _initInputs(XrayProfileState state) {
    nameController.text = state.name;
    dnsClientIpController.text = state.dns.clientIp;
    dnsServeExpiredTTLController.text = state.dns.serveExpiredTTL;
    fakeDnsIpv4IpPoolController.text = state.fakeDns.ipv4.ipPool;
    fakeDnsIpv4PoolSizeController.text = state.fakeDns.ipv4.poolSize;
    fakeDnsIpv6IpPoolController.text = state.fakeDns.ipv6.ipPool;
    fakeDnsIpv6PoolSizeController.text = state.fakeDns.ipv6.poolSize;
  }

  void updateSection(XrayProfileUISection section) {
    if (section != state.section) {
      emit(state.copyWith(section: section, version: state.version + 1));
    }
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    _mergeInputToState(_xrayProfileState);
    final text = JsonTool.encoder.convert(_xrayProfileState.xrayJson.toJson());
    final params = XrayRawEditParams(
      AppLocalizations.of(context)!.xrayProfileUIPageTitle,
      text,
    );
    final newText = await context.pushScoped<String>(
      AppSecondaryDestination.xrayRawEdit,
      extra: params,
    );
    if (newText != null) {
      final state = XrayProfileState();
      state.readFromText(newText);
      _updateState(state);
    }
  }

  Future<void> editTun(BuildContext context) async {
    final params = InboundTunParams(_xrayProfileState.inbounds.tun);
    final tun = await context.pushScoped<InboundTunState>(
      AppSecondaryDestination.inboundTun,
      extra: params,
    );
    if (tun != null) {
      _xrayProfileState.inbounds.tun = tun;
      _notifyChanged();
    }
  }

  Future<void> editPing(BuildContext context) async {
    final params = InboundPingParams(_xrayProfileState.inbounds.ping);
    await context.pushScoped<InboundPingState>(
      AppSecondaryDestination.inboundPing,
      extra: params,
    );
  }

  Future<void> editFreedom(BuildContext context) async {
    final params = OutboundFreedomParams(_xrayProfileState.outbounds.freedom);
    final freedom = await context.pushScoped<OutboundFreedomState>(
      AppSecondaryDestination.outboundFreedom,
      extra: params,
    );
    if (freedom != null) {
      _xrayProfileState.outbounds.freedom = freedom;
      _notifyChanged();
    }
  }

  Future<void> editFragment(BuildContext context) async {
    final params = OutboundFragmentParams(_xrayProfileState.outbounds.fragment);
    final fragment = await context.pushScoped<OutboundFragmentState>(
      AppSecondaryDestination.outboundFragment,
      extra: params,
    );
    if (fragment != null) {
      _xrayProfileState.outbounds.fragment = fragment;
      _notifyChanged();
    }
  }

  Future<void> editBlackHole(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.outboundBlackHole);
  }

  Future<void> editOutboundDns(BuildContext context) async {
    final outbounds = _xrayProfileState.outbounds;
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

  Future<void> importFinalOutbound(BuildContext context) async {
    final outbound = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: OutboundSelectParams(),
    );
    if (outbound == null) {
      return;
    }
    final finalOutbound = OutboundState();
    var valid = false;
    try {
      valid = finalOutbound.readFromDbData(outbound);
    } catch (_) {
      valid = false;
    }
    if (!valid) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.finalOutboundValidationInvalid,
        );
      }
      return;
    }
    finalOutbound.name = outbound.name;
    finalOutbound.tag = RoutingOutboundTag.chainProxy.name;
    finalOutbound.dialerProxy = "";
    _xrayProfileState.outbounds.finalOutbound = finalOutbound;
    _notifyChanged();
  }

  void deleteFinalOutbound() {
    _xrayProfileState.outbounds.finalOutbound = null;
    _xrayProfileState.outbounds.fixDnsDialerProxy();
    _notifyChanged();
  }

  void updateDomainStrategy(String value) {
    final domainStrategy = RoutingDomainStrategy.fromString(value);
    if (domainStrategy != null) {
      _xrayProfileState.routing.domainStrategy = domainStrategy;
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
    final dnsOutboundTags = _dnsRoutingOutboundTags();
    final params = RoutingRuleDnsQueryParams(
      _xrayProfileState.routing.dnsQueryRule,
      dnsOutboundTags,
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsQuery,
      extra: params,
    );
    if (rule != null) {
      _xrayProfileState.routing.dnsQueryRule = rule;
      _notifyChanged();
    }
  }

  Future<void> _showDnsOutRule(BuildContext context) async {
    final params = RoutingRuleDnsOutParams(
      _xrayProfileState.routing.dnsOutRule,
    );
    await context.pushScoped(
      AppSecondaryDestination.routingRuleDnsOut,
      extra: params,
    );
  }

  Future<void> _showDnsDoTRule(BuildContext context) async {
    final dnsOutboundTags = _dnsRoutingOutboundTags();
    final params = RoutingRuleDnsDoTParams(
      _xrayProfileState.routing.dnsDoTRule,
      dnsOutboundTags,
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsDot,
      extra: params,
    );
    if (rule != null) {
      _xrayProfileState.routing.dnsDoTRule = rule;
      _notifyChanged();
    }
  }

  List<String> _dnsRoutingOutboundTags() {
    return _xrayProfileState.outbounds.outboundTags
        .where((tag) => tag.isNotEmpty && tag != RoutingOutboundTag.block.name)
        .toList();
  }

  void appendCustomRule() {
    _xrayProfileState.routing.customRules.add(RoutingRuleState());
    _notifyChanged();
  }

  void sortCustomRule(int oldIndex, int newIndex) {
    final rules = _xrayProfileState.routing.customRules;
    final rule = rules.removeAt(oldIndex);
    rules.insert(newIndex, rule);
    _notifyChanged();
  }

  Future<void> editCustomRule(BuildContext context, int index) async {
    final params = RoutingRuleParams(
      _xrayProfileState.routing.customRules[index],
      _xrayProfileState.outbounds.outboundTags,
      _routingInboundTags(_xrayProfileState.dns),
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRule,
      extra: params,
    );
    if (rule != null) {
      _xrayProfileState.routing.customRules[index] = rule;
      _notifyChanged();
    }
  }

  void deleteCustomRule(int index) {
    _xrayProfileState.routing.customRules.removeAt(index);
    _notifyChanged();
  }

  List<String> _routingInboundTags(DnsState dns) {
    return <String>{
      ...RoutingInboundTag.userVisibleNames,
      ...dns.inboundTags,
    }.toList();
  }

  void updateDisableCache(bool value) {
    _xrayProfileState.dns.disableCache = value;
    _notifyChanged();
  }

  void updateServeStale(bool value) {
    _xrayProfileState.dns.serveStale = value;
    _notifyChanged();
  }

  void updateDisableFallback(bool value) {
    _xrayProfileState.dns.disableFallback = value;
    _notifyChanged();
  }

  void updateDisableFallbackIfMatch(bool value) {
    _xrayProfileState.dns.disableFallbackIfMatch = value;
    _notifyChanged();
  }

  void updateEnableParallelQuery(bool value) {
    _xrayProfileState.dns.enableParallelQuery = value;
    _notifyChanged();
  }

  void updateUseSystemHosts(bool value) {
    _xrayProfileState.dns.useSystemHosts = value;
    _notifyChanged();
  }

  Future<void> editHosts(BuildContext context) async {
    final params = DnsHostsParams(_xrayProfileState.dns.hosts);
    final hosts = await context.pushScoped<Map<String, List<String>>>(
      AppSecondaryDestination.dnsHosts,
      extra: params,
    );
    if (hosts != null) {
      _xrayProfileState.dns.hosts = hosts;
      _notifyChanged();
    }
  }

  void appendDnsServer() {
    _xrayProfileState.dns.servers.add(_newDnsServer());
    _notifyChanged();
  }

  void sortDnsServer(int oldIndex, int newIndex) {
    final servers = _xrayProfileState.dns.servers;
    final server = servers.removeAt(oldIndex);
    servers.insert(newIndex, server);
    _notifyChanged();
  }

  Future<void> editDnsServer(BuildContext context, int index) async {
    final params = DnsServerParams(_xrayProfileState.dns.servers[index]);
    final server = await context.pushScoped<DnsServerState>(
      AppSecondaryDestination.dnsServer,
      extra: params,
    );
    if (server != null) {
      _xrayProfileState.dns.servers[index] = server;
      _notifyChanged();
    }
  }

  void deleteDnsServer(int index) {
    _xrayProfileState.dns.servers.removeAt(index);
    _notifyChanged();
  }

  void updateLogLevel(String value) {
    final logLevel = XrayLogLevel.fromString(value);
    if (logLevel != null) {
      _xrayProfileState.log.logLevel = logLevel;
      _notifyChanged();
    }
  }

  void updateDnsLog(bool value) {
    _xrayProfileState.log.dnsLog = value;
    _notifyChanged();
  }

  void updateMaskAddress(String value) {
    final maskAddress = XrayLogMaskAddress.fromString(value);
    if (maskAddress != null) {
      _xrayProfileState.log.maskAddress = maskAddress;
      _notifyChanged();
    }
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(_xrayProfileState);
    final checked = await _validate(context);
    if (!checked) {
      return;
    }
    if (params.id == DBConstants.defaultId) {
      await _xrayProfileState.insertToDb();
    } else if (_xrayProfileData != null) {
      await _xrayProfileState.updateToDb(_xrayProfileData!);
      final eventBus = AppEventBus.instance;
      if (params.id == eventBus.state.xrayProfileId) {
        eventBus.updateXrayProfileId(eventBus.state.xrayProfileId);
      }
    }
    if (context.mounted) {
      context.pop();
    }
  }

  void _mergeInputToState(XrayProfileState state) {
    state.name = nameController.text;
    state.dns.clientIp = dnsClientIpController.text;
    state.dns.serveExpiredTTL = dnsServeExpiredTTLController.text;
    state.fakeDns.ipv4.ipPool = fakeDnsIpv4IpPoolController.text;
    state.fakeDns.ipv4.poolSize = fakeDnsIpv4PoolSizeController.text;
    state.fakeDns.ipv6.ipPool = fakeDnsIpv6IpPoolController.text;
    state.fakeDns.ipv6.poolSize = fakeDnsIpv6PoolSizeController.text;
    state.removeWhitespace();
  }

  Future<bool> _validate(BuildContext context) async {
    final localMessage = _validateLocalFields(context);
    if (localMessage != null) {
      ContextAlert.showToast(context, localMessage);
      return false;
    }
    final tuple = await _xrayProfileState.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }

  String? _validateLocalFields(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ipv4Error = _xrayProfileState.fakeDns.validateIPv4();
    if (ipv4Error != null) {
      return "${l10n.fakeDnsPageIPv4}: ${_fakeDnsErrorMessage(l10n, ipv4Error)}";
    }
    final ipv6Error = _xrayProfileState.fakeDns.validateIPv6();
    if (ipv6Error != null) {
      return "${l10n.fakeDnsPageIPv6}: ${_fakeDnsErrorMessage(l10n, ipv6Error)}";
    }
    return null;
  }

  String _fakeDnsErrorMessage(
    AppLocalizations l10n,
    FakeDnsValidationError error,
  ) {
    return switch (error) {
      FakeDnsValidationError.ipPoolRequired =>
        l10n.fakeDnsValidationIpPoolRequired,
      FakeDnsValidationError.ipPoolInvalid =>
        l10n.fakeDnsValidationIpPoolInvalid,
      FakeDnsValidationError.poolSizeInvalid =>
        l10n.fakeDnsValidationPoolSizeInvalid,
      FakeDnsValidationError.poolSizeTooLarge =>
        l10n.fakeDnsValidationPoolSizeTooLarge,
    };
  }

  void _notifyChanged() {
    if (isPageActive) {
      emit(state.bumped());
    }
  }
}
