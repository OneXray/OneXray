import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/ping.dart';
import 'package:onexray/service/xray/raw/validator.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';
import 'package:uuid/uuid.dart';

class XrayRawController {
  final XrayRawParams params;
  XrayRawController(this.params) {
    _initParams();
    _queryOutbound();
  }

  var _configId = DBConstants.defaultId;
  CoreConfigData? _configData;

  final controller = TextEditingController();

  void dispose() {
    controller.dispose();
  }

  void _initParams() {
    _configId = params.id;
  }

  Future<void> _queryOutbound() async {
    final db = AppDatabase();
    if (_configId != DBConstants.defaultId) {
      final config = await db.coreConfigDao.searchRow(_configId);
      if (config != null) {
        _configData = config;
        if (EmptyTool.checkString(config.data)) {
          final text = XrayRawDb.readFromDbData(config);
          controller.text = text;
        }
      }
    } else {
      controller.text = _templateXrayJson;
    }
  }

  String get _templateXrayJson {
    final settings = XraySettingState();
    final outbound = OutboundState();
    outbound.address = "example.com";
    outbound.port = "443";
    outbound.vlessId = Uuid().v4();
    settings.outbounds.outbounds.add(outbound);

    return JsonTool.encoderForFile.convert(settings.xrayJson.toJson());
  }

  Future<void> realPing(BuildContext context) async {
    final rawText = controller.text.trim();
    final check = await XrayRawValidator.validate(rawText);
    if (check.item1) {
      final eventBus = AppEventBus.instance;
      eventBus.updatePinging(true);
      final pingState = PingState();
      await pingState.readFromPreferences();
      final res = await XrayRawPing.ping(rawText, pingState);
      eventBus.updatePinging(false);
      if (context.mounted) {
        await ContextAlert.showPingResultDialog(context, res);
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(context, check.item2);
      }
    }
  }

  Future<void> save(BuildContext context) async {
    final rawText = controller.text.trim();
    final check = await XrayRawValidator.validate(rawText);
    if (check.item1) {
      await _updateDb(rawText);
      if (context.mounted) {
        context.pop();
      }
    } else {
      if (context.mounted) {
        ContextAlert.showToast(context, check.item2);
      }
    }
  }

  Future<void> _updateDb(String rawText) async {
    final name = _readName(rawText);
    if (_configId == DBConstants.defaultId) {
      await XrayRawDb.insertToDb(name, rawText);
    } else {
      if (_configData != null) {
        await XrayRawDb.updateToDb(name, rawText, _configData!);
      }
    }
  }

  String _readName(String rawText) {
    final jsonMap = JsonTool.decoder.convert(rawText);
    final xrayJson = XrayJson.fromJson(jsonMap);
    if (EmptyTool.checkString(xrayJson.name)) {
      return xrayJson.name!;
    } else {
      return "Unnamed";
    }
  }
}
