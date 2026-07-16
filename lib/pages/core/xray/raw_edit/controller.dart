import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/json_importer.dart';
import 'package:re_editor/re_editor.dart';

class XrayRawEditPageState {
  final bool validJson;
  final int lineCount;

  const XrayRawEditPageState({this.validJson = false, this.lineCount = 1});
}

class XrayRawEditController extends PageCubit<XrayRawEditPageState> {
  final XrayRawEditParams params;
  XrayRawEditController(this.params) : super(const XrayRawEditPageState()) {
    controller.addListener(_updateEditorState);
    _initParams();
  }

  final controller = CodeLineEditingController();

  @override
  Future<void> disposePageResources() async {
    controller.removeListener(_updateEditorState);
    controller.dispose();
  }

  void _updateEditorState() {
    final text = controller.text;
    var validJson = false;
    try {
      JsonTool.decoder.convert(text);
      validJson = true;
    } catch (_) {
      validJson = false;
    }
    if (isPageActive) {
      emit(
        XrayRawEditPageState(
          validJson: validJson,
          lineCount: controller.lineCount,
        ),
      );
    }
  }

  void _initParams() {
    controller.text = params.text;
  }

  Future<void> importAction(BuildContext context, IconMenuId menuId) async {
    switch (menuId) {
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
    final lastLineIndex = controller.lineCount - 1;
    controller.selection = CodeLineSelection.collapsed(
      index: lastLineIndex,
      offset: controller.codeLines[lastLineIndex].length,
    );
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
