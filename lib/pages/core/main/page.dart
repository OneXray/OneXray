import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/main/controller.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

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
    return DefaultTextStyle.merge(
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
                  NavigationSettingRow(
                    title: localizations.tunSettingUIPageTitle,
                    onTap: () => controller.gotoTun(context),
                  ),
                  NavigationSettingRow(
                    title: localizations.pingPageTitle,
                    onTap: () => controller.gotoPing(context),
                  ),
                  NavigationSettingRow(
                    title: localizations.logPageTitle,
                    onTap: () => controller.gotoLogs(context),
                  ),
                ],
              ),
              SettingSection(
                title: localizations.settingPageSectionData,
                children: [
                  NavigationSettingRow(
                    title: localizations.xraySettingListPageTitle,
                    onTap: () => controller.gotoXray(context),
                  ),
                  NavigationSettingRow(
                    title: localizations.geoDataListPageTitle,
                    onTap: () => controller.gotoGeoData(context),
                  ),
                  if (!AppPlatform.isIOS)
                    NavigationSettingRow(
                      title: localizations.settingPageEnhancedRouting,
                      onTap: () {
                        controller.openEnhancedRouting();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
