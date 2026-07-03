import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/log/controller.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/constants.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogController(),
      child: BlocBuilder<LogController, LogPageState>(
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
        child: ResponsiveContent(
          child: Column(
            children: [
              if (!hideLogFiles) _logSection(context, controller),
              _configSection(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logSection(BuildContext context, LogController controller) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.logPageLogFile,
      children: [
        SettingRow(
          title: localizations.logPageAccess,
          showChevron: true,
          onTap: () => controller.gotoLogFile(
            context,
            localizations.logPageAccess,
            XrayStateConstants.accessLogPath,
          ),
          trailing: AppMenuButton<IconMenuId>(
            icon: Icons.more_vert,
            entries: iconMenuEntries([
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
            ]),
            onSelected: (menuId) => controller.moreAction(
              context,
              XrayStateConstants.accessLogPath,
              menuId,
            ),
          ),
        ),
        SettingRow(
          title: localizations.logPageError,
          showChevron: true,
          onTap: () => controller.gotoLogFile(
            context,
            localizations.logPageError,
            XrayStateConstants.errorLogPath,
          ),
          trailing: AppMenuButton<IconMenuId>(
            icon: Icons.more_vert,
            entries: iconMenuEntries([
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
            ]),
            onSelected: (menuId) => controller.moreAction(
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
