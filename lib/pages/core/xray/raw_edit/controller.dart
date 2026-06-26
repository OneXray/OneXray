import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/json_importer.dart';

class XrayRawEditController extends Cubit<int> {
  final XrayRawEditParams params;
  XrayRawEditController(this.params) : super(0) {
    _initParams();
  }

  final controller = TextEditingController();

  @override
  Future<void> close() {
    controller.dispose();
    return super.close();
  }

  void _initParams() {
    controller.text = params.text;
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

  Future<void> save(BuildContext context) async {
    final rawText = controller.text.trim();
    try {
      JsonTool.decoder.convert(rawText);
    } catch (_) {
      _showJsonInvalid(context);
      return;
    }
    if (context.mounted) {
      context.pop(rawText);
    }
  }
}
