import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';

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
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["txt", "json", "yaml"],
      );
      if (result == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _showJsonInvalid(context);
        return;
      }
      final text = await File(path).readAsString();
      if (!context.mounted) {
        return;
      }
      _importText(context, text);
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  Future<void> readPasteboard(BuildContext context) async {
    try {
      final hasStrings = await Clipboard.hasStrings();
      if (!context.mounted) {
        return;
      }
      if (!hasStrings) {
        _showJsonInvalid(context);
        return;
      }
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted) {
        return;
      }
      final text = data?.text;
      if (text == null) {
        _showJsonInvalid(context);
        return;
      }
      _importText(context, text);
    } catch (_) {
      if (context.mounted) {
        _showJsonInvalid(context);
      }
    }
  }

  void _importText(BuildContext context, String text) {
    final rawText = text.trim();
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      controller.text = JsonTool.encoderForFile.convert(decoded);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    } catch (_) {
      _showJsonInvalid(context);
    }
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
