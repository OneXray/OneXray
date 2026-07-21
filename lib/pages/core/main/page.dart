import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/main/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CorePage extends StatelessWidget {
  const CorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CoreRootController()..init(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.mainNavigationCore),
        ),
        body: const SafeArea(child: CoreContent()),
      ),
    );
  }
}

class CoreContent extends StatelessWidget {
  const CoreContent({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CoreRootController>();
    final localizations = AppLocalizations.of(context)!;
    return BlocBuilder<CoreRootController, CorePageState>(
      builder: (context, pageState) =>
          BlocBuilder<AppEventBus, AppEventBusState>(
            bloc: AppEventBus.instance,
            builder: (context, eventState) => SingleChildScrollView(
              child: ResponsiveContent(
                desktopMaxWidth: 1040,
                adaptiveBreakpoint: 900,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final network = _networkSection(
                      context,
                      controller,
                      eventState,
                      localizations,
                    );
                    final data = _dataSection(
                      context,
                      controller,
                      localizations,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: network),
                              Expanded(child: data),
                            ],
                          )
                        else ...[
                          network,
                          data,
                        ],
                        _logSection(
                          context,
                          controller,
                          pageState,
                          localizations,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
    );
  }

  Widget _networkSection(
    BuildContext context,
    CoreRootController controller,
    AppEventBusState eventState,
    AppLocalizations localizations,
  ) {
    return SettingSection(
      title: localizations.settingsPageSectionNetwork,
      children: [
        if (CoreRunModePolicy.proxyEnabled)
          SelectSettingRow<CoreRunMode>(
            title: localizations.coreRunModeTitle,
            subtitle: localizations.corePageRunModeDescription,
            leading: const Icon(LucideIcons.gauge),
            value: eventState.coreRunMode.title,
            selections: CoreRunMode.values,
            titleBuilder: (mode) => mode.title,
            onSelected: controller.updateRunMode,
          ),
        NavigationSettingRow(
          title: localizations.tunSettingsPageTitle,
          subtitle: localizations.corePageTunSettingsDescription,
          leading: const Icon(LucideIcons.shield),
          onTap: () => controller.gotoTun(context),
        ),
        NavigationSettingRow(
          title: localizations.pingPageTitle,
          subtitle: localizations.corePagePingDescription,
          leading: const Icon(LucideIcons.activity),
          onTap: () => controller.gotoPing(context),
        ),
      ],
    );
  }

  Widget _dataSection(
    BuildContext context,
    CoreRootController controller,
    AppLocalizations localizations,
  ) {
    return SettingSection(
      title: localizations.settingsPageSectionData,
      children: [
        NavigationSettingRow(
          title: localizations.xrayProfileListPageTitle,
          subtitle: localizations.corePageXrayProfilesDescription,
          leading: const Icon(LucideIcons.gitBranch),
          onTap: () => controller.gotoXray(context),
        ),
        NavigationSettingRow(
          title: localizations.geoDataListPageTitle,
          subtitle: localizations.corePageRuleSetDescription,
          leading: const Icon(LucideIcons.database),
          onTap: () => controller.gotoGeoData(context),
        ),
        NavigationSettingRow(
          title: localizations.corePageImportEnhancedRouting,
          subtitle: localizations.corePageImportEnhancedRoutingDescription,
          leading: const Icon(LucideIcons.import),
          onTap: () => controller.openEnhancedRouting(context),
        ),
      ],
    );
  }

  Widget _logSection(
    BuildContext context,
    CoreRootController controller,
    CorePageState state,
    AppLocalizations localizations,
  ) {
    return SettingSection(
      title: localizations.logPageTitle,
      children: [
        if (!state.hideLogFiles)
          _logFileRow(
            context,
            controller,
            title: localizations.logPageAccess,
            subtitle: localizations.corePageAccessLogDescription,
            path: XrayStateConstants.accessLogPath,
            icon: LucideIcons.fileText,
          ),
        if (!state.hideLogFiles)
          _logFileRow(
            context,
            controller,
            title: localizations.logPageError,
            subtitle: localizations.corePageErrorLogDescription,
            path: XrayStateConstants.errorLogPath,
            icon: LucideIcons.squareTerminal,
          ),
        NavigationSettingRow(
          title: localizations.logPageXrayConfig,
          subtitle: localizations.corePageXrayConfigDescription,
          leading: const Icon(LucideIcons.fileJson),
          onTap: () => controller.gotoXrayConfigFile(context),
        ),
      ],
    );
  }

  Widget _logFileRow(
    BuildContext context,
    CoreRootController controller, {
    required String title,
    required String subtitle,
    required String path,
    required IconData icon,
  }) {
    return SettingRow(
      title: title,
      subtitle: subtitle,
      leading: Icon(icon),
      onTap: () => controller.gotoLogFile(context, title, path),
      trailing: ActionCluster(
        children: [
          AppMenuButton<IconMenuId>(
            icon: LucideIcons.ellipsis,
            entries: iconMenuEntries([
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
            ]),
            onSelected: (menuId) =>
                controller.moreLogAction(context, path, menuId),
          ),
          const Icon(LucideIcons.chevronRight),
        ],
      ),
    );
  }
}
