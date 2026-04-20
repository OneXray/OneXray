import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/home/xray/setting/dns/params.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/log/params.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/home/xray/setting/routing/params.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/setting/dns_state.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';
import 'package:onexray/service/xray/setting/routing_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_db.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/setting/state_validator.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';

class XraySettingUIController {
  final XraySettingUIParams params;
  XraySettingUIController(this.params) {
    _queryXraySetting();
  }

  CoreConfigData? _xraySettingData;

  var _xraySettingState = XraySettingState();
  void dispose() {
    nameController.dispose();
  }

  Future<void> _queryXraySetting() async {
    final db = AppDatabase();
    if (params.id != DBConstants.defaultId) {
      final xraySetting = await db.coreConfigDao.searchRow(params.id);
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
  }

  void _initInputs(XraySettingState state) {
    nameController.text = state.name;
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    final xrayJson = _xraySettingState.xrayJson;
    final jsonMap = xrayJson.toJson();
    final text = JsonTool.encoderForFile.convert(jsonMap);
    final params = XrayRawEditParams(text);
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
    }
  }

  Future<void> editDns(BuildContext context) async {
    final params = DnsParams(_xraySettingState.dns);
    final dns = await context.push<DnsState>(RouterPath.dns, extra: params);
    if (dns != null) {
      _xraySettingState.dns = dns;
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
    }
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
}
