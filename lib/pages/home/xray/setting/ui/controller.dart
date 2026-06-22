import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/xray/setting/dns/params.dart';
import 'package:onexray/pages/home/xray/setting/fake_dns/params.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/log/params.dart';
import 'package:onexray/pages/home/xray/setting/metrics/params.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/policy/params.dart';
import 'package:onexray/pages/home/xray/setting/routing/params.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/setting/dns_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/fake_dns_state.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/metrics_state.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';
import 'package:onexray/service/xray/setting/routing_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_db.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/setting/state_validator.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';

class XraySettingUICubitState {
  final int version;

  const XraySettingUICubitState({this.version = 0});

  factory XraySettingUICubitState.initial() => const XraySettingUICubitState();

  XraySettingUICubitState bumped() =>
      XraySettingUICubitState(version: version + 1);
}

class XraySettingUIController extends Cubit<XraySettingUICubitState> {
  final XraySettingUIParams params;

  XraySettingUIController(this.params)
    : super(XraySettingUICubitState.initial()) {
    _queryXraySetting();
  }

  CoreConfigData? _xraySettingData;

  var _xraySettingState = XraySettingState();

  @override
  Future<void> close() {
    nameController.dispose();
    return super.close();
  }

  Future<void> _queryXraySetting() async {
    final db = AppDatabase();
    if (params.id != DBConstants.defaultId) {
      final xraySetting = await db.coreConfigDao.searchRow(params.id);
      if (isClosed) {
        return;
      }
      if (xraySetting != null) {
        _xraySettingData = xraySetting;

        final state = XraySettingState();
        state.readFromDbData(xraySetting);
        _updateState(state);
      }
    } else {
      _initInputs(_xraySettingState);
    }
  }

  void _updateState(XraySettingState state) {
    _initInputs(state);
    _xraySettingState = state;
    _notifyChanged();
  }

  void _initInputs(XraySettingState state) {
    nameController.text = state.name;
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    final xrayJson = _xraySettingState.xrayJson;
    final jsonMap = xrayJson.toJson();
    final text = JsonTool.encoderForFile.convert(jsonMap);
    final params = XrayRawEditParams(
      AppLocalizations.of(context)!.xraySettingUIPageTitle,
      text,
    );
    final newText = await context.push<String>(
      RouterPath.xrayRawEdit,
      extra: params,
    );
    if (newText != null) {
      final state = XraySettingState();
      state.readFromText(newText);
      _updateState(state);
    }
  }

  final nameController = TextEditingController();

  Future<void> editLog(BuildContext context) async {
    final params = XrayLogParams(_xraySettingState.log);
    final log = await context.push<LogState>(RouterPath.xrayLog, extra: params);
    if (log != null) {
      _xraySettingState.log = log;
      _notifyChanged();
    }
  }

  Future<void> showMetrics(BuildContext context) async {
    final params = MetricsParams(_xraySettingState.metrics);
    final metrics = await context.push<MetricsState>(
      RouterPath.metrics,
      extra: params,
    );
    if (metrics != null) {
      _xraySettingState.metrics = metrics;
      _notifyChanged();
    }
  }

  void showPolicy(BuildContext context) {
    final params = PolicyParams(_xraySettingState.policy);
    context.push(RouterPath.policy, extra: params);
  }

  Future<void> editDns(BuildContext context) async {
    final params = DnsParams(_xraySettingState.dns);
    final dns = await context.push<DnsState>(RouterPath.dns, extra: params);
    if (dns != null) {
      _xraySettingState.dns = dns;
      _notifyChanged();
    }
  }

  Future<void> editFakeDns(BuildContext context) async {
    final params = FakeDnsParams(_xraySettingState.fakeDns);
    final fakeDns = await context.push<FakeDnsPoolsState>(
      RouterPath.fakeDns,
      extra: params,
    );
    if (fakeDns != null) {
      _xraySettingState.fakeDns = fakeDns;
      _notifyChanged();
    }
  }

  Future<void> editRouting(BuildContext context) async {
    final params = RoutingParams(
      _xraySettingState.routing,
      _xraySettingState.outbounds.outboundTags,
    );
    final routing = await context.push<RoutingState>(
      RouterPath.routing,
      extra: params,
    );
    if (routing != null) {
      _xraySettingState.routing = routing;
      _notifyChanged();
    }
  }

  Future<void> editInbounds(BuildContext context) async {
    final params = InboundsParams(_xraySettingState.inbounds);
    final inbounds = await context.push<InboundsState>(
      RouterPath.inbounds,
      extra: params,
    );
    if (inbounds != null) {
      _xraySettingState.inbounds = inbounds;
      _notifyChanged();
    }
  }

  Future<void> editOutbounds(BuildContext context) async {
    final params = OutboundsParams(_xraySettingState.outbounds);
    final outbounds = await context.push<OutboundsState>(
      RouterPath.outbounds,
      extra: params,
    );
    if (outbounds != null) {
      _xraySettingState.outbounds = outbounds;
      _notifyChanged();
    }
  }

  String logSummary(BuildContext context) {
    final log = _xraySettingState.log;
    return log.logLevel.name;
  }

  String dnsSummary(BuildContext context) {
    final dns = _xraySettingState.dns;
    return dns.queryStrategy.name;
  }

  String fakeDnsSummary(BuildContext context) {
    final queryStrategy = _xraySettingState.dns.queryStrategy;
    switch (queryStrategy) {
      case DnsQueryStrategy.useIP:
        return "IPv4 + IPv6";
      case DnsQueryStrategy.useIPv4:
        return "IPv4";
      case DnsQueryStrategy.useIPv6:
        return "IPv6";
    }
  }

  String statsSummary(BuildContext context) {
    return _xraySettingState.stats.enabled
        ? AppLocalizations.of(context)!.switchEnabled
        : AppLocalizations.of(context)!.chainProxyPageDisabled;
  }

  String metricsSummary(BuildContext context) {
    final metrics = _xraySettingState.metrics;
    return metrics.enabled
        ? metrics.displayListen
        : AppLocalizations.of(context)!.chainProxyPageDisabled;
  }

  String policySummary(BuildContext context) {
    final system = _xraySettingState.policy.system;
    return system.statsInboundUplink &&
            system.statsInboundDownlink &&
            system.statsOutboundUplink &&
            system.statsOutboundDownlink
        ? AppLocalizations.of(context)!.switchEnabled
        : AppLocalizations.of(context)!.chainProxyPageDisabled;
  }

  String routingSummary(BuildContext context) {
    final routing = _xraySettingState.routing;
    return routing.domainStrategy.name;
  }

  String inboundsSummary(BuildContext context) {
    final sniffing = _xraySettingState.inbounds.tun.sniffing;
    return sniffing.enabled
        ? AppLocalizations.of(context)!.switchEnabled
        : AppLocalizations.of(context)!.chainProxyPageDisabled;
  }

  String outboundsSummary(BuildContext context) {
    final chainProxy = _xraySettingState.outbounds.chainProxy;
    if (chainProxy == null) {
      return AppLocalizations.of(context)!.chainProxyPageDisabled;
    }
    return chainProxy.name;
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(_xraySettingState);
    final checked = await _validate(context);
    if (checked) {
      if (params.id == DBConstants.defaultId) {
        await _xraySettingState.insertToDb();
      } else {
        if (_xraySettingData != null) {
          await _xraySettingState.updateToDb(_xraySettingData!);
          final eventBus = AppEventBus.instance;
          if (params.id == eventBus.state.xraySettingId) {
            eventBus.updateXraySettingId(eventBus.state.xraySettingId);
          }
        }
      }
      if (context.mounted) {
        context.pop();
      }
    }
  }

  void _mergeInputToState(XraySettingState state) {
    _mergeInput(state);

    state.removeWhitespace();
  }

  void _mergeInput(XraySettingState state) {
    state.name = nameController.text;
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await _xraySettingState.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }

  void _notifyChanged() {
    if (!isClosed) {
      emit(state.bumped());
    }
  }
}
