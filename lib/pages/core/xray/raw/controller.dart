import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/json_importer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/ping.dart';
import 'package:onexray/service/xray/raw/validator.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';
import 'package:uuid/uuid.dart';

class XrayRawController extends Cubit<int> {
  final XrayRawParams params;
  XrayRawController(this.params) : super(0) {
    _initParams();
    _queryOutbound();
  }

  var _configId = DBConstants.defaultId;
  CoreConfigData? _configData;

  final controller = TextEditingController();

  @override
  Future<void> close() {
    controller.dispose();
    return super.close();
  }

  void _initParams() {
    _configId = params.id;
  }

  Future<void> _queryOutbound() async {
    final db = AppDatabase();
    if (_configId != DBConstants.defaultId) {
      final config = await db.coreConfigDao.searchRow(_configId);
      if (isClosed) {
        return;
      }
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

  Future<void> importAction(BuildContext context, String menuId) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    switch (id) {
      case IconMenuId.pickFile:
        await pickFile(context);
        break;
      case IconMenuId.readPasteboard:
        await readPasteboard(context);
        break;
      default:
        break;
    }
  }

  Future<void> pickFile(BuildContext context) async {
    await _applyImportResult(context, JsonImporter.pickFile);
  }

  Future<void> readPasteboard(BuildContext context) async {
    await _applyImportResult(context, JsonImporter.readPasteboard);
  }

  Future<void> _applyImportResult(
    BuildContext context,
    Future<JsonImportResult> Function() importText,
  ) async {
    final result = await importText();
    if (!context.mounted || result.isCanceled) {
      return;
    }

    final text = result.text;
    if (text == null) {
      _showJsonInvalid(context);
      return;
    }

    _updateEditorText(text);
  }

  void _updateEditorText(String text) {
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _showJsonInvalid(BuildContext context) {
    ContextAlert.showToast(
      context,
      AppLocalizations.of(context)!.validationJsonInvalid,
    );
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
      final id = await XrayRawDb.insertToDb(name, rawText);
      PingService().schedulePingConfigIds([id]);
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
