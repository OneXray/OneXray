import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/outbounds/params.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/core/xray/profile/dns/params.dart';
import 'package:onexray/pages/core/xray/profile/routing/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_db.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_validator.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';
import 'package:onexray/core/model/xray_standard.dart';

class XrayFullConfigPageState {
  final int version;

  const XrayFullConfigPageState({this.version = 0});

  factory XrayFullConfigPageState.initial() => const XrayFullConfigPageState();

  XrayFullConfigPageState bumped() =>
      XrayFullConfigPageState(version: version + 1);
}

class XrayFullConfigController extends Cubit<XrayFullConfigPageState> {
  final XrayFullConfigParams params;

  XrayFullConfigController(this.params)
    : super(XrayFullConfigPageState.initial()) {
    _queryFullConfig();
  }

  CoreConfigData? _configData;
  var _fullConfigState = XrayFullConfigState();

  final nameController = TextEditingController();

  @override
  Future<void> close() {
    nameController.dispose();
    return super.close();
  }

  Future<void> _queryFullConfig() async {
    if (params.id != DBConstants.defaultId) {
      final db = AppDatabase();
      final config = await db.coreConfigDao.searchRow(params.id);
      if (isClosed) {
        return;
      }
      if (config != null) {
        _configData = config;
        final state = XrayFullConfigState();
        state.readFromDbData(config);
        _updateState(state);
      }
    } else {
      _initInputs(_fullConfigState);
    }
  }

  void _updateState(XrayFullConfigState state) {
    _initInputs(state);
    _fullConfigState = state;
    _notifyChanged();
  }

  void _initInputs(XrayFullConfigState state) {
    nameController.text = state.name;
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

  Future<void> editOutbounds(BuildContext context) async {
    final params = XrayFullConfigOutboundsParams(
      _copyOutbounds(_fullConfigState.outbounds),
    );
    final result = await context.pushScoped<XrayFullConfigOutboundsResult>(
      AppSecondaryDestination.xrayFullConfigOutbounds,
      extra: params,
    );
    if (result != null) {
      _applyOutboundTagRenames(result.tagRenames);
      _fullConfigState.outbounds = result.outbounds;
      _notifyChanged();
    }
  }

  void _applyOutboundTagRenames(Map<String, String> tagRenames) {
    if (tagRenames.isEmpty) {
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
      final newTag = tagRenames[rule.outboundTag];
      if (newTag != null) {
        rule.outboundTag = newTag;
      }
    }
  }

  OutboundsState _copyOutbounds(OutboundsState outbounds) {
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.outbounds = outbounds.xrayJson;
    final copy = OutboundsState();
    copy.readFromXrayJson(xrayJson);
    return copy;
  }

  Future<void> editRouting(BuildContext context) async {
    final params = RoutingParams(
      _fullConfigState.routing,
      _fullConfigState.outbounds.outboundTags,
      _routingInboundTags(_fullConfigState.dns),
    );
    final routing = await context.pushScoped<RoutingState>(
      AppSecondaryDestination.routing,
      extra: params,
    );
    if (routing != null) {
      _fullConfigState.routing = routing;
      _notifyChanged();
    }
  }

  List<String> _routingInboundTags(DnsState dns) {
    return <String>{
      ...RoutingInboundTag.userVisibleNames,
      ...dns.inboundTags,
    }.toList();
  }

  Future<void> editDns(BuildContext context) async {
    final params = DnsParams(_fullConfigState.dns);
    final dns = await context.pushScoped<DnsState>(
      AppSecondaryDestination.dns,
      extra: params,
    );
    if (dns != null) {
      _fullConfigState.dns = dns;
      _notifyChanged();
    }
  }

  String outboundsSummary(BuildContext context) {
    final proxy = _fullConfigState.outbounds.outbounds
        .where((outbound) => outbound.tag == RoutingOutboundTag.proxy.name)
        .firstOrNull;
    if (proxy == null) {
      return AppLocalizations.of(context)!.xrayFullConfigProxyMissing;
    }
    final count = _fullConfigState.outbounds.outbounds.length;
    return "${proxy.name} ($count)";
  }

  String routingSummary(BuildContext context) {
    return _fullConfigState.routing.domainStrategy.name;
  }

  String dnsSummary(BuildContext context) {
    final dns = _fullConfigState.dns;
    if (dns.servers.isEmpty) {
      return AppLocalizations.of(context)!.finalOutboundPageDisabled;
    }
    final firstServer = dns.servers.first.address;
    if (dns.servers.length == 1) {
      return firstServer;
    }
    return "$firstServer (+${dns.servers.length - 1})";
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

  void _mergeInputToState(XrayFullConfigState state) {
    state.name = nameController.text;
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
    if (!isClosed) {
      emit(state.bumped());
    }
  }
}
