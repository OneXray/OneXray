import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/main/controller.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class CorePage extends StatelessWidget {
  const CorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CoreRootController(),
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
    return BlocBuilder<AppEventBus, AppEventBusState>(
      bloc: AppEventBus.instance,
      builder: (context, eventState) => DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14),
        child: SingleChildScrollView(
          child: ResponsiveContent(
            desktopMaxWidth: 1040,
            adaptiveBreakpoint: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingSection(
                  title: localizations.settingPageSectionNetwork,
                  children: [
                    SelectSettingRow<CoreRunMode>(
                      title: localizations.coreRunModeTitle,
                      value: eventState.coreRunMode.title,
                      selections: CoreRunMode.values,
                      onSelected: controller.updateRunMode,
                    ),
                    NavigationSettingRow(
                      title: localizations.tunSettingUIPageTitle,
                      leading: const Icon(Icons.vpn_lock_outlined),
                      onTap: () => controller.gotoTun(context),
                    ),
                    NavigationSettingRow(
                      title: localizations.pingPageTitle,
                      leading: const Icon(Icons.speed_outlined),
                      onTap: () => controller.gotoPing(context),
                    ),
                    NavigationSettingRow(
                      title: localizations.logPageTitle,
                      leading: const Icon(Icons.article_outlined),
                      onTap: () => controller.gotoLogs(context),
                    ),
                  ],
                ),
                SettingSection(
                  title: localizations.settingPageSectionData,
                  children: [
                    NavigationSettingRow(
                      title: localizations.xraySettingListPageTitle,
                      leading: const Icon(Icons.hub_outlined),
                      onTap: () => controller.gotoXray(context),
                    ),
                    NavigationSettingRow(
                      title: localizations.geoDataListPageTitle,
                      leading: const Icon(Icons.public_outlined),
                      onTap: () => controller.gotoGeoData(context),
                    ),
                    NavigationSettingRow(
                      title: localizations.corePageImportEnhancedRouting,
                      leading: const Icon(Icons.route_outlined),
                      onTap: () => controller.openEnhancedRouting(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
