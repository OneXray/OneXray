import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/core/xray/profile/dns/params.dart';
import 'package:onexray/pages/core/xray/profile/fake_dns/params.dart';
import 'package:onexray/pages/core/xray/profile/inbounds/params.dart';
import 'package:onexray/pages/core/xray/profile/log/params.dart';
import 'package:onexray/pages/core/xray/profile/outbounds/params.dart';
import 'package:onexray/pages/core/xray/profile/routing/params.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/fake_dns_state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_db.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
import 'package:onexray/service/xray/profile/state_writer.dart';
import 'package:onexray/pages/main/navigation.dart';

class XrayProfileUIPageState {
  final int version;

  const XrayProfileUIPageState({this.version = 0});

  factory XrayProfileUIPageState.initial() => const XrayProfileUIPageState();

  XrayProfileUIPageState bumped() =>
      XrayProfileUIPageState(version: version + 1);
}

class XrayProfileUIController extends Cubit<XrayProfileUIPageState> {
  final XrayProfileUIParams params;

  XrayProfileUIController(this.params)
    : super(XrayProfileUIPageState.initial()) {
    _queryXrayProfile();
  }

  CoreConfigData? _xrayProfileData;

  var _xrayProfileState = XrayProfileState();

  @override
  Future<void> close() {
    nameController.dispose();
    return super.close();
  }

  Future<void> _queryXrayProfile() async {
    final db = AppDatabase();
    if (params.id != DBConstants.defaultId) {
      final xrayProfile = await db.coreConfigDao.searchRow(params.id);
      if (isClosed) {
        return;
      }
      if (xrayProfile != null) {
        _xrayProfileData = xrayProfile;

        final state = XrayProfileState();
        state.readFromDbData(xrayProfile);
        _updateState(state);
      }
    } else {
      _initInputs(_xrayProfileState);
    }
  }

  void _updateState(XrayProfileState state) {
    _initInputs(state);
    _xrayProfileState = state;
    _notifyChanged();
  }

  void _initInputs(XrayProfileState state) {
    nameController.text = state.name;
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    final xrayJson = _xrayProfileState.xrayJson;
    final jsonMap = xrayJson.toJson();
    final text = JsonTool.encoder.convert(jsonMap);
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

  final nameController = TextEditingController();

  Future<void> editLog(BuildContext context) async {
    final params = XrayLogParams(_xrayProfileState.log);
    final log = await context.pushScoped<LogState>(
      AppSecondaryDestination.xrayLog,
      extra: params,
    );
    if (log != null) {
      _xrayProfileState.log = log;
      _notifyChanged();
    }
  }

  Future<void> editDns(BuildContext context) async {
    final params = DnsParams(_xrayProfileState.dns);
    final dns = await context.pushScoped<DnsState>(
      AppSecondaryDestination.dns,
      extra: params,
    );
    if (dns != null) {
      _xrayProfileState.dns = dns;
      _notifyChanged();
    }
  }

  Future<void> editFakeDns(BuildContext context) async {
    final params = FakeDnsParams(_xrayProfileState.fakeDns);
    final fakeDns = await context.pushScoped<FakeDnsPoolsState>(
      AppSecondaryDestination.fakeDns,
      extra: params,
    );
    if (fakeDns != null) {
      _xrayProfileState.fakeDns = fakeDns;
      _notifyChanged();
    }
  }

  Future<void> editRouting(BuildContext context) async {
    final params = RoutingParams(
      _xrayProfileState.routing,
      _xrayProfileState.outbounds.outboundTags,
      _routingInboundTags(_xrayProfileState.dns),
    );
    final routing = await context.pushScoped<RoutingState>(
      AppSecondaryDestination.routing,
      extra: params,
    );
    if (routing != null) {
      _xrayProfileState.routing = routing;
      _notifyChanged();
    }
  }

  List<String> _routingInboundTags(DnsState dns) {
    return <String>{
      ...RoutingInboundTag.userVisibleNames,
      ...dns.inboundTags,
    }.toList();
  }

  Future<void> editInbounds(BuildContext context) async {
    final params = InboundsParams(_xrayProfileState.inbounds);
    final inbounds = await context.pushScoped<InboundsState>(
      AppSecondaryDestination.inbounds,
      extra: params,
    );
    if (inbounds != null) {
      _xrayProfileState.inbounds = inbounds;
      _notifyChanged();
    }
  }

  Future<void> editOutbounds(BuildContext context) async {
    final params = OutboundsParams(_xrayProfileState.outbounds);
    final outbounds = await context.pushScoped<OutboundsState>(
      AppSecondaryDestination.outbounds,
      extra: params,
    );
    if (outbounds != null) {
      _xrayProfileState.outbounds = outbounds;
      _notifyChanged();
    }
  }

  String logSummary(BuildContext context) {
    final log = _xrayProfileState.log;
    return log.logLevel.name;
  }

  String dnsSummary(BuildContext context) {
    final dns = _xrayProfileState.dns;
    if (dns.servers.isEmpty) {
      return AppLocalizations.of(context)!.finalOutboundPageDisabled;
    }
    final firstServer = dns.servers.first.address;
    if (dns.servers.length == 1) {
      return firstServer;
    }
    return "$firstServer (+${dns.servers.length - 1})";
  }

  String fakeDnsSummary(BuildContext context) {
    return AppLocalizations.of(context)!.xrayProfileDnsControlledByTunIPv6;
  }

  String routingSummary(BuildContext context) {
    final routing = _xrayProfileState.routing;
    return routing.domainStrategy.name;
  }

  String inboundsSummary(BuildContext context) {
    final sniffing = _xrayProfileState.inbounds.tun.sniffing;
    return sniffing.enabled
        ? AppLocalizations.of(context)!.switchEnabled
        : AppLocalizations.of(context)!.finalOutboundPageDisabled;
  }

  String outboundsSummary(BuildContext context) {
    final finalOutbound = _xrayProfileState.outbounds.finalOutbound;
    if (finalOutbound == null) {
      return AppLocalizations.of(context)!.finalOutboundPageDisabled;
    }
    return finalOutbound.name;
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(_xrayProfileState);
    final checked = await _validate(context);
    if (checked) {
      if (params.id == DBConstants.defaultId) {
        await _xrayProfileState.insertToDb();
      } else {
        if (_xrayProfileData != null) {
          await _xrayProfileState.updateToDb(_xrayProfileData!);
          final eventBus = AppEventBus.instance;
          if (params.id == eventBus.state.xrayProfileId) {
            eventBus.updateXrayProfileId(eventBus.state.xrayProfileId);
          }
        }
      }
      if (context.mounted) {
        context.pop();
      }
    }
  }

  void _mergeInputToState(XrayProfileState state) {
    _mergeInput(state);

    state.removeWhitespace();
  }

  void _mergeInput(XrayProfileState state) {
    state.name = nameController.text;
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await _xrayProfileState.validate();
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
