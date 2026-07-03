import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:onexray/pages/main/navigation.dart';

class LogPageState {
  final bool hideLogFiles;

  const LogPageState({required this.hideLogFiles});

  factory LogPageState.initial() =>
      LogPageState(hideLogFiles: AppPlatform.isMacOS);
}

class LogController extends Cubit<LogPageState> {
  LogController() : super(LogPageState.initial()) {
    _init();
  }

  Future<void> _init() async {
    var hideLogFiles = false;
    try {
      if (AppPlatform.isMacOS) {
        hideLogFiles = await AppHostApi().useSystemExtension();
      }
    } catch (e) {
      ygLogger("LogController init error: $e");
    }
    if (!isClosed) {
      emit(LogPageState(hideLogFiles: hideLogFiles));
    }
  }

  void moreAction(BuildContext context, String path, IconMenuId menuId) {
    switch (menuId) {
      case IconMenuId.share:
        _shareFile(context, path);
        break;
      case IconMenuId.save:
        _saveFile(context, path);
        break;
      default:
        break;
    }
  }

  Future<void> _shareFile(BuildContext context, String path) async {
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    final params = ShareParams(
      files: [XFile(path)],
      fileNameOverrides: [p.basename(path)],
      sharePositionOrigin: sharePositionOrigin,
    );
    await SharePlus.instance.share(params);
  }

  Future<void> _saveFile(BuildContext context, String path) async {
    await FileTool.saveFile(path, p.basename(path), ".txt");
  }

  void gotoLogFile(BuildContext context, String title, String path) {
    final params = LogFileViewerParams(title: title, path: path);
    context.pushScoped(AppSecondaryDestination.logFile, extra: params);
  }

  void gotoXrayConfigFile(BuildContext context) {
    final params = ConfigFileViewerParams(
      AppLocalizations.of(context)!.logPageXrayConfig,
      XrayStateConstants.configFilePath,
    );
    context.pushScoped(AppSecondaryDestination.configFileViewer, extra: params);
  }
}
