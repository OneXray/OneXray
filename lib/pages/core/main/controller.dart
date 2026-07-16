import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class CorePageState {
  final bool hideLogFiles;

  const CorePageState({required this.hideLogFiles});

  factory CorePageState.initial() =>
      CorePageState(hideLogFiles: AppPlatform.isMacOS);

  CorePageState copyWith({bool? hideLogFiles}) {
    return CorePageState(hideLogFiles: hideLogFiles ?? this.hideLogFiles);
  }
}

class CoreRootController extends PageCubit<CorePageState> {
  CoreRootController() : super(CorePageState.initial());

  Future<void> init() async {
    var hideLogFiles = false;
    try {
      if (AppPlatform.isMacOS) {
        hideLogFiles = await AppHostApi().useSystemExtension();
      }
    } catch (e) {
      ygLogger("CoreRootController initLogFiles error: $e");
    }
    if (isPageActive) {
      emit(state.copyWith(hideLogFiles: hideLogFiles));
    }
  }

  Future<void> updateRunMode(CoreRunMode mode) async {
    await VpnService().switchRunMode(mode);
  }

  void gotoTun(BuildContext context) {
    context.goScoped(AppSecondaryDestination.tun);
  }

  void gotoPing(BuildContext context) {
    context.goScoped(AppSecondaryDestination.ping);
  }

  void gotoXray(BuildContext context) {
    context.goScoped(AppSecondaryDestination.xray);
  }

  void gotoGeoData(BuildContext context) {
    context.goScoped(
      AppSecondaryDestination.geoData,
      extra: GeoDataListParams(GeoDataListType.full, GeoDatCodesMode.show),
    );
  }

  final _routingTemplates = Uri.parse("https://github.com/OneXray/Routing");

  Future<void> openEnhancedRouting(BuildContext context) async {
    try {
      await launchUrl(_routingTemplates);
    } catch (e) {
      ygLogger("openEnhancedRouting error: $e");
    }
  }

  void moreLogAction(BuildContext context, String path, IconMenuId menuId) {
    switch (menuId) {
      case IconMenuId.share:
        _shareFile(context, path);
        break;
      case IconMenuId.save:
        _saveFile(path);
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
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        fileNameOverrides: [p.basename(path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> _saveFile(String path) async {
    await FileTool.saveFile(path, p.basename(path), ".txt");
  }

  void gotoLogFile(BuildContext context, String title, String path) {
    context.pushScoped(
      AppSecondaryDestination.logFile,
      extra: LogFileViewerParams(title: title, path: path),
    );
  }

  void gotoXrayConfigFile(BuildContext context) {
    context.pushScoped(
      AppSecondaryDestination.configFileViewer,
      extra: ConfigFileViewerParams(
        AppLocalizations.of(context)!.logPageXrayConfig,
        XrayStateConstants.configFilePath,
      ),
    );
  }
}
