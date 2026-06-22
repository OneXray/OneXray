import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/log/controller.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/constants.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogController(),
      child: BlocBuilder<LogController, LogCubitState>(
        builder: (context, state) {
          final controller = context.read<LogController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.logPageTitle),
            ),
            body: SafeArea(
              child: _body(context, controller, state.hideLogFiles),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LogController controller,
    bool hideLogFiles,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (!hideLogFiles) _logSection(context, controller),
            _configSection(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _logSection(BuildContext context, LogController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.logPageLogFile,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.logPageAccess,
          trailing: IconMenuPicker(
            icon: Icons.more_vert,
            menus: [
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
            ],
            callback: (menuId) => controller.moreAction(
              context,
              XrayStateConstants.accessLogPath,
              menuId,
            ),
          ),
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.logPageError,
          trailing: IconMenuPicker(
            icon: Icons.more_vert,
            menus: [
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
            ],
            callback: (menuId) => controller.moreAction(
              context,
              XrayStateConstants.errorLogPath,
              menuId,
            ),
          ),
        ),
      ],
    );
  }

  Widget _configSection(BuildContext context, LogController controller) {
    return SettingSection(
      title: "",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.logPageXrayConfig,
          onTap: () => controller.gotoXrayConfigFile(context),
        ),
      ],
    );
  }
}
